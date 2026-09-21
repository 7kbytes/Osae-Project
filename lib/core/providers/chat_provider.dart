import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/chat_model.dart';
import '../repositories/chat_repository.dart';
import '../services/firebase_service.dart';
import '../services/local_storage_service.dart';

class ChatProvider with ChangeNotifier {
  final ChatRepository _chatRepository;
  final LocalStorageService _localStorageService;
  StreamSubscription<List<ChatRoom>>? _roomsSubscription;
  final Map<String, StreamSubscription<List<ChatMessage>>>
  _messageSubscriptions = {};

  final Map<String, List<ChatMessage>> _messagesPerRoom = {};
  List<ChatRoom> _rooms = [];
  String _currentUserId = '';

  ChatProvider({
    ChatRepository? chatRepository,
    LocalStorageService? localStorageService,
    required String currentUserId,
  }) : _chatRepository =
           chatRepository ??
           (FirebaseService.isInitialized
               ? FirestoreChatRepository()
               : InMemoryChatRepository()),
       _localStorageService =
           localStorageService ?? LocalStorageService.instance {
    _initData(currentUserId);
  }

  void _initData(String currentUserId) {
    _currentUserId = currentUserId;
    final cachedRooms = _localStorageService.getChatRooms();
    if (cachedRooms.isNotEmpty) {
      _rooms = List.from(cachedRooms);
      for (final r in _rooms) {
        final cachedMsgs = _localStorageService.getMessages(r.id);
        if (cachedMsgs.isNotEmpty) {
          _messagesPerRoom[r.id] = List.from(cachedMsgs);
        }
      }
    } else if (_chatRepository is InMemoryChatRepository) {
      final inMemory = _chatRepository;
      _rooms = List<ChatRoom>.from(inMemory.rooms);
      for (final r in _rooms) {
        final msgs = inMemory.getMessages(r.id);
        _messagesPerRoom[r.id] = List<ChatMessage>.from(msgs);
        _localStorageService.saveMessages(r.id, msgs);
      }
      _localStorageService.saveChatRooms(_rooms);
    }

    _subscribeToRooms(currentUserId);
  }

  void _subscribeToRooms(String userId) {
    _roomsSubscription?.cancel();
    _loadError = null;
    _isLoading = FirebaseService.isInitialized && _rooms.isEmpty;
    _roomsSubscription = _chatRepository
        .getChatRoomsStream(userId)
        .listen(
          (updatedRooms) {
            final wasLoading = _isLoading || _loadError != null;
            _isLoading = false;
            _loadError = null;
            // Against Firestore an empty list is real; offline/demo keeps the cache.
            if (updatedRooms.isNotEmpty || FirebaseService.isInitialized) {
              _rooms = List.from(updatedRooms);
              _localStorageService.saveChatRooms(_rooms);
              notifyListeners();
            } else if (wasLoading) {
              notifyListeners();
            }
          },
          onError: (Object e) {
            debugPrint('Chat rooms stream error: $e');
            _isLoading = false;
            _loadError = 'Could not load chats. Check your connection.';
            notifyListeners();
          },
        );
  }

  bool _isLoading = false;
  String? _loadError;

  /// True until the first chat list arrives from the backend.
  bool get isLoading => _isLoading;

  /// Set when the live chat list could not be loaded.
  String? get loadError => _loadError;

  /// Re-subscribes to the chat list after a failure.
  void retryLoad() {
    if (_currentUserId.isEmpty) return;
    _subscribeToRooms(_currentUserId);
    notifyListeners();
  }

  /// Re-binds the provider to the signed-in user (called when auth changes).
  void setCurrentUser(String userId) {
    if (userId == _currentUserId) return;
    _currentUserId = userId;
    for (final s in _messageSubscriptions.values) {
      s.cancel();
    }
    _messageSubscriptions.clear();
    _messagesPerRoom.clear();
    _loadingRooms.clear();
    _messageErrors.clear();
    _roomErrors.clear();
    _rooms = [];
    _isLoading = false;
    _loadError = null;
    if (userId.isNotEmpty) _subscribeToRooms(userId);
    notifyListeners();
  }

  List<ChatRoom> get rooms => List.unmodifiable(_rooms);

  List<ChatMessage> getMessages(String roomId) {
    if (!_messagesPerRoom.containsKey(roomId)) {
      final cached = _localStorageService.getMessages(roomId);
      if (cached.isNotEmpty) {
        _messagesPerRoom[roomId] = List.from(cached);
      }
    }

    if (!_messageSubscriptions.containsKey(roomId)) {
      _subscribeToMessages(roomId);
    }
    return List.unmodifiable(_messagesPerRoom[roomId] ?? []);
  }

  final Set<String> _loadingRooms = {};
  final Map<String, String> _messageErrors = {};
  final Map<String, String> _roomErrors = {};

  void _subscribeToMessages(String roomId) {
    _messageErrors.remove(roomId);
    if (FirebaseService.isInitialized && _messagesPerRoom[roomId] == null) {
      _loadingRooms.add(roomId);
    }
    _messageSubscriptions[roomId] = _chatRepository
        .getMessagesStream(roomId)
        .listen(
          (messages) {
            _loadingRooms.remove(roomId);
            _messageErrors.remove(roomId);
            _messagesPerRoom[roomId] = List.from(messages);
            _localStorageService.saveMessages(roomId, messages);
            notifyListeners();
          },
          onError: (Object e) {
            debugPrint('Chat messages stream error ($roomId): $e');
            _loadingRooms.remove(roomId);
            _messageErrors[roomId] =
                'Could not load messages. Check your connection.';
            notifyListeners();
          },
        );
  }

  /// True until the first batch of messages for [roomId] arrives.
  bool isLoadingMessages(String roomId) => _loadingRooms.contains(roomId);

  /// Set when the messages for [roomId] could not be loaded.
  String? messagesError(String roomId) => _messageErrors[roomId];

  /// Set when the backend refused to create the chat room [roomId].
  String? roomError(String roomId) => _roomErrors[roomId];

  /// Re-subscribes to the messages for [roomId] after a failure.
  void retryMessages(String roomId) {
    _messageSubscriptions.remove(roomId)?.cancel();
    _subscribeToMessages(roomId);
    notifyListeners();
  }

  String getOrCreateRoom({
    required String jobId,
    required String jobTitle,
    required String seekerId,
    required String seekerName,
    required String posterId,
    required String posterName,
  }) {
    final existingRoom = _rooms.firstWhere(
      (r) => r.jobId == jobId && r.seekerId == seekerId,
      orElse: () => ChatRoom(
        id: '',
        jobId: '',
        jobTitle: '',
        seekerId: '',
        seekerName: '',
        posterId: '',
        posterName: '',
        lastMessage: '',
        updatedAt: DateTime.now(),
      ),
    );

    if (existingRoom.id.isNotEmpty) {
      return existingRoom.id;
    }

    final newRoomId = ChatRoom.idFor(jobId, seekerId);
    final newRoom = ChatRoom(
      id: newRoomId,
      jobId: jobId,
      jobTitle: jobTitle,
      seekerId: seekerId,
      seekerName: seekerName,
      posterId: posterId,
      posterName: posterName,
      lastMessage: 'Chat started for $jobTitle',
      updatedAt: DateTime.now(),
    );

    _rooms.insert(0, newRoom);
    final initialMsgs = [
      ChatMessage(
        id: 'msg_init_${DateTime.now().millisecondsSinceEpoch}',
        senderId: seekerId,
        senderName: seekerName,
        text: 'Hello, I am interested in your job posting: $jobTitle.',
        timestamp: DateTime.now(),
        isRead: true,
      ),
    ];
    _messagesPerRoom[newRoomId] = initialMsgs;

    _localStorageService.saveChatRooms(_rooms);
    _localStorageService.saveMessages(newRoomId, initialMsgs);

    _roomErrors.remove(newRoomId);
    notifyListeners();

    // Created in the background; if the backend refuses, undo the local room
    // so the user is not left chatting into a room that does not exist.
    _chatRepository
        .getOrCreateChatRoom(
          jobId: jobId,
          jobTitle: jobTitle,
          seekerId: seekerId,
          seekerName: seekerName,
          posterId: posterId,
          posterName: posterName,
        )
        .catchError((Object e) {
          debugPrint('ChatProvider.getOrCreateRoom error: $e');
          _rooms.removeWhere((r) => r.id == newRoomId);
          _messagesPerRoom.remove(newRoomId);
          _localStorageService.saveChatRooms(_rooms);
          _localStorageService.saveMessages(newRoomId, const []);
          _roomErrors[newRoomId] =
              'Could not start this chat. Please try again.';
          notifyListeners();
          return newRoomId;
        });

    return newRoomId;
  }

  String? _sendError;

  /// Set when the last message could not be sent; cleared on the next send.
  String? get sendError => _sendError;

  /// Shows the message immediately, then removes it again and sets
  /// [sendError] if the backend rejects it. Returns whether it was saved.
  Future<bool> sendMessage({
    required String roomId,
    required String senderId,
    required String senderName,
    required String text,
  }) async {
    if (text.trim().isEmpty) return false;
    _sendError = null;

    final newMessage = ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      senderId: senderId,
      senderName: senderName,
      text: text.trim(),
      timestamp: DateTime.now(),
      isRead: false,
    );

    if (!_messagesPerRoom.containsKey(roomId)) {
      _messagesPerRoom[roomId] = [];
    }

    _messagesPerRoom[roomId]!.add(newMessage);

    final roomIndex = _rooms.indexWhere((r) => r.id == roomId);
    final previousRoom = roomIndex != -1 ? _rooms[roomIndex] : null;
    if (roomIndex != -1) {
      final updatedRoom = _rooms[roomIndex].copyWith(
        lastMessage: text.trim(),
        updatedAt: DateTime.now(),
      );
      _rooms.removeAt(roomIndex);
      _rooms.insert(0, updatedRoom);
    }

    _localStorageService.saveMessages(roomId, _messagesPerRoom[roomId]!);
    _localStorageService.saveChatRooms(_rooms);

    notifyListeners();

    try {
      await _chatRepository.sendMessage(roomId, newMessage);
    } catch (e) {
      debugPrint('ChatProvider.sendMessage error: $e');
      _messagesPerRoom[roomId]?.removeWhere((m) => m.id == newMessage.id);
      if (previousRoom != null) {
        final i = _rooms.indexWhere((r) => r.id == roomId);
        if (i != -1) _rooms[i] = previousRoom;
      }
      _localStorageService.saveMessages(roomId, _messagesPerRoom[roomId] ?? []);
      _localStorageService.saveChatRooms(_rooms);
      _sendError = 'Message not sent. Please try again.';
      notifyListeners();
      return false;
    }
    return true;
  }

  @override
  void dispose() {
    _roomsSubscription?.cancel();
    for (final sub in _messageSubscriptions.values) {
      sub.cancel();
    }
    super.dispose();
  }
}
