import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_model.dart';

abstract class ChatRepository {
  Stream<List<ChatRoom>> getChatRoomsStream(String userId);
  Stream<List<ChatMessage>> getMessagesStream(String chatRoomId);
  Future<String> getOrCreateChatRoom({
    required String jobId,
    required String jobTitle,
    required String seekerId,
    required String seekerName,
    required String posterId,
    required String posterName,
  });
  Future<void> sendMessage(String roomId, ChatMessage message);
}

class FirestoreChatRepository implements ChatRepository {
  final FirebaseFirestore _firestore;

  FirestoreChatRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _chatsCollection =>
      _firestore.collection('chats');

  @override
  Stream<List<ChatRoom>> getChatRoomsStream(String userId) {
    return _chatsCollection
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ChatRoom.fromMap(doc.data(), doc.id))
          .where((room) => room.seekerId == userId || room.posterId == userId)
          .toList();
    });
  }

  @override
  Stream<List<ChatMessage>> getMessagesStream(String chatRoomId) {
    return _chatsCollection
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ChatMessage.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  @override
  Future<String> getOrCreateChatRoom({
    required String jobId,
    required String jobTitle,
    required String seekerId,
    required String seekerName,
    required String posterId,
    required String posterName,
  }) async {
    final existingSnapshot = await _chatsCollection
        .where('jobId', isEqualTo: jobId)
        .where('seekerId', isEqualTo: seekerId)
        .limit(1)
        .get();

    if (existingSnapshot.docs.isNotEmpty) {
      return existingSnapshot.docs.first.id;
    }

    final docRef = _chatsCollection.doc();
    final newRoom = ChatRoom(
      id: docRef.id,
      jobId: jobId,
      jobTitle: jobTitle,
      seekerId: seekerId,
      seekerName: seekerName,
      posterId: posterId,
      posterName: posterName,
      lastMessage: 'Chat started for $jobTitle',
      updatedAt: DateTime.now(),
    );

    await docRef.set(newRoom.toMap());

    // Send initial greeting message
    final initMessage = ChatMessage(
      id: _firestore.collection('tmp').doc().id,
      senderId: seekerId,
      senderName: seekerName,
      text: 'Hello, I am interested in your job posting: $jobTitle.',
      timestamp: DateTime.now(),
      isRead: true,
    );
    await docRef.collection('messages').doc(initMessage.id).set(initMessage.toMap());

    return docRef.id;
  }

  @override
  Future<void> sendMessage(String roomId, ChatMessage message) async {
    final batch = _firestore.batch();
    final messageRef = _chatsCollection.doc(roomId).collection('messages').doc(message.id);
    final roomRef = _chatsCollection.doc(roomId);

    batch.set(messageRef, message.toMap());
    batch.update(roomRef, {
      'lastMessage': message.text,
      'updatedAt': message.timestamp.toIso8601String(),
    });

    await batch.commit();
  }
}

class InMemoryChatRepository implements ChatRepository {
  final List<ChatRoom> _rooms = [];
  final Map<String, List<ChatMessage>> _messagesPerRoom = {};

  final StreamController<List<ChatRoom>> _roomsController =
      StreamController<List<ChatRoom>>.broadcast();
  final Map<String, StreamController<List<ChatMessage>>> _messageControllers = {};

  InMemoryChatRepository() {
    _initDemoData();
  }

  void _initDemoData() {
    final demoRoom = ChatRoom(
      id: 'chat_101',
      jobId: 'job_101',
      jobTitle: 'Market Offloader & Heavy Carrier',
      seekerId: 'seeker_001',
      seekerName: 'Kofi Mensah',
      posterId: 'poster_001',
      posterName: 'Akosua Wholesale',
      lastMessage: 'Great! Come to Container 14 near the VIP bus park.',
      updatedAt: DateTime.now().subtract(const Duration(minutes: 15)),
    );

    _rooms.add(demoRoom);

    _messagesPerRoom['chat_101'] = [
      ChatMessage(
        id: 'msg_1',
        senderId: 'poster_001',
        senderName: 'Akosua Wholesale',
        text: 'Hello Kofi, are you available today at Circle VIP terminal?',
        timestamp: DateTime.now().subtract(const Duration(minutes: 45)),
        isRead: true,
      ),
      ChatMessage(
        id: 'msg_2',
        senderId: 'seeker_001',
        senderName: 'Kofi Mensah',
        text: 'Yes Madam Akosua! I am near Kwame Nkrumah Circle now.',
        timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
        isRead: true,
      ),
      ChatMessage(
        id: 'msg_3',
        senderId: 'poster_001',
        senderName: 'Akosua Wholesale',
        text: 'Great! Come to Container 14 near the VIP bus park.',
        timestamp: DateTime.now().subtract(const Duration(minutes: 15)),
        isRead: true,
      ),
    ];
  }

  void _notifyRooms() {
    if (!_roomsController.isClosed) {
      _roomsController.add(List.unmodifiable(_rooms));
    }
  }

  void _notifyMessages(String roomId) {
    final controller = _messageControllers[roomId];
    if (controller != null && !controller.isClosed) {
      controller.add(List.unmodifiable(_messagesPerRoom[roomId] ?? []));
    }
  }

  List<ChatRoom> get rooms => List.unmodifiable(_rooms);
  List<ChatMessage> getMessages(String roomId) =>
      List.unmodifiable(_messagesPerRoom[roomId] ?? []);

  @override
  Stream<List<ChatRoom>> getChatRoomsStream(String userId) {
    Timer.run(_notifyRooms);
    return _roomsController.stream.map((list) {
      return list
          .where((room) =>
              userId.isEmpty || room.seekerId == userId || room.posterId == userId)
          .toList();
    });
  }

  @override
  Stream<List<ChatMessage>> getMessagesStream(String chatRoomId) {
    if (!_messageControllers.containsKey(chatRoomId)) {
      _messageControllers[chatRoomId] =
          StreamController<List<ChatMessage>>.broadcast();
    }
    Timer.run(() => _notifyMessages(chatRoomId));
    return _messageControllers[chatRoomId]!.stream;
  }

  @override
  Future<String> getOrCreateChatRoom({
    required String jobId,
    required String jobTitle,
    required String seekerId,
    required String seekerName,
    required String posterId,
    required String posterName,
  }) async {
    final index = _rooms.indexWhere(
      (r) => r.jobId == jobId && r.seekerId == seekerId,
    );

    if (index != -1) {
      return _rooms[index].id;
    }

    final newRoomId = 'chat_${DateTime.now().millisecondsSinceEpoch}';
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
    _messagesPerRoom[newRoomId] = [
      ChatMessage(
        id: 'msg_init_${DateTime.now().millisecondsSinceEpoch}',
        senderId: seekerId,
        senderName: seekerName,
        text: 'Hello, I am interested in your job posting: $jobTitle.',
        timestamp: DateTime.now(),
        isRead: true,
      ),
    ];

    _notifyRooms();
    _notifyMessages(newRoomId);

    return newRoomId;
  }

  @override
  Future<void> sendMessage(String roomId, ChatMessage message) async {
    if (message.text.trim().isEmpty) return;

    if (!_messagesPerRoom.containsKey(roomId)) {
      _messagesPerRoom[roomId] = [];
    }

    _messagesPerRoom[roomId]!.add(message);

    final roomIndex = _rooms.indexWhere((r) => r.id == roomId);
    if (roomIndex != -1) {
      final updatedRoom = _rooms[roomIndex].copyWith(
        lastMessage: message.text.trim(),
        updatedAt: message.timestamp,
      );
      _rooms.removeAt(roomIndex);
      _rooms.insert(0, updatedRoom);
    }

    _notifyRooms();
    _notifyMessages(roomId);
  }
}
