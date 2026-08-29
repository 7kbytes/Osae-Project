import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_model.dart';
import '../models/job_application_model.dart';
import '../models/job_model.dart';
import '../models/user_model.dart';

/// LocalStorageService handles robust local JSON persistence and retrieval
/// backed by [SharedPreferences] for hybrid local-first offline support.
class LocalStorageService {
  static const String keyUser = 'local_job_connector_user';
  static const String keyJobs = 'local_job_connector_jobs';
  static const String keyFavorites = 'local_job_connector_favorites';
  static const String keyChatRooms = 'local_job_connector_chat_rooms';
  static const String keyMessagesPrefix = 'local_job_connector_messages_';
  static const String keyApplications = 'local_job_connector_applications';

  static LocalStorageService? _instance;
  SharedPreferences? _prefs;

  LocalStorageService({SharedPreferences? prefs}) {
    _prefs = prefs;
  }

  /// Singleton accessor
  static LocalStorageService get instance {
    _instance ??= LocalStorageService();
    return _instance!;
  }

  /// Initialize SharedPreferences instance
  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Allow injecting pre-initialized SharedPreferences (e.g., for tests)
  void setPreferences(SharedPreferences prefs) {
    _prefs = prefs;
  }

  SharedPreferences get prefs {
    if (_prefs == null) {
      throw StateError(
        'LocalStorageService has not been initialized. Call init() or provide SharedPreferences instance first.',
      );
    }
    return _prefs!;
  }

  bool get isInitialized => _prefs != null;

  // ---------------------------------------------------------------------------
  // User Profile Persistence
  // ---------------------------------------------------------------------------

  Future<void> saveUser(AppUser user) async {
    try {
      if (!isInitialized) return;
      final jsonString = jsonEncode(user.toMap());
      await prefs.setString(keyUser, jsonString);
    } catch (e) {
      debugPrint('LocalStorageService.saveUser error: $e');
    }
  }

  AppUser? getUser() {
    try {
      if (!isInitialized) return null;
      final raw = _prefs?.getString(keyUser);
      if (raw == null || raw.trim().isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return AppUser.fromMap(decoded, decoded['id'] ?? '');
      }
    } catch (e) {
      debugPrint('LocalStorageService.getUser error: $e');
    }
    return null;
  }

  Future<void> clearUser() async {
    try {
      if (isInitialized) {
        await prefs.remove(keyUser);
      }
    } catch (e) {
      debugPrint('LocalStorageService.clearUser error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Jobs Persistence
  // ---------------------------------------------------------------------------

  Future<void> saveJobs(List<JobPost> jobs) async {
    try {
      if (!isInitialized) return;
      final list = jobs.map((job) {
        final map = job.toMap();
        map['isFavorite'] = job.isFavorite;
        return map;
      }).toList();
      await prefs.setString(keyJobs, jsonEncode(list));
    } catch (e) {
      debugPrint('LocalStorageService.saveJobs error: $e');
    }
  }

  List<JobPost> getJobs() {
    try {
      if (!isInitialized) return [];
      final raw = _prefs?.getString(keyJobs);
      if (raw == null || raw.trim().isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        final result = <JobPost>[];
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            try {
              result.add(JobPost.fromMap(item, item['id'] ?? ''));
            } catch (itemError) {
              debugPrint('Error parsing cached JobPost: $itemError');
            }
          }
        }
        return result;
      }
    } catch (e) {
      debugPrint('LocalStorageService.getJobs error: $e');
    }
    return [];
  }

  // ---------------------------------------------------------------------------
  // Favorites Persistence
  // ---------------------------------------------------------------------------

  Future<void> saveFavorites(Set<String> ids) async {
    try {
      if (!isInitialized) return;
      await prefs.setStringList(keyFavorites, ids.toList());
    } catch (e) {
      debugPrint('LocalStorageService.saveFavorites error: $e');
    }
  }

  Set<String> getFavorites() {
    try {
      if (!isInitialized) return {};
      final list = _prefs?.getStringList(keyFavorites);
      if (list != null) {
        return list.toSet();
      }
    } catch (e) {
      debugPrint('LocalStorageService.getFavorites error: $e');
    }
    return {};
  }

  // Aliases for compatibility
  Future<void> saveFavoriteIds(Set<String> ids) => saveFavorites(ids);
  Set<String> getFavoriteIds() => getFavorites();

  // ---------------------------------------------------------------------------
  // Chat Rooms Persistence
  // ---------------------------------------------------------------------------

  Future<void> saveChatRooms(List<ChatRoom> rooms) async {
    try {
      if (!isInitialized) return;
      final list = rooms.map((room) => room.toMap()).toList();
      await prefs.setString(keyChatRooms, jsonEncode(list));
    } catch (e) {
      debugPrint('LocalStorageService.saveChatRooms error: $e');
    }
  }

  List<ChatRoom> getChatRooms() {
    try {
      if (!isInitialized) return [];
      final raw = _prefs?.getString(keyChatRooms);
      if (raw == null || raw.trim().isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        final result = <ChatRoom>[];
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            try {
              result.add(ChatRoom.fromMap(item, item['id'] ?? ''));
            } catch (itemError) {
              debugPrint('Error parsing cached ChatRoom: $itemError');
            }
          }
        }
        return result;
      }
    } catch (e) {
      debugPrint('LocalStorageService.getChatRooms error: $e');
    }
    return [];
  }

  // ---------------------------------------------------------------------------
  // Chat Messages Persistence
  // ---------------------------------------------------------------------------

  String _messageKey(String roomId) => '$keyMessagesPrefix$roomId';

  Future<void> saveMessages(String roomId, List<ChatMessage> messages) async {
    try {
      if (!isInitialized) return;
      final list = messages.map((m) => m.toMap()).toList();
      await prefs.setString(_messageKey(roomId), jsonEncode(list));
    } catch (e) {
      debugPrint('LocalStorageService.saveMessages error: $e');
    }
  }

  List<ChatMessage> getMessages(String roomId) {
    try {
      if (!isInitialized) return [];
      final raw = _prefs?.getString(_messageKey(roomId));
      if (raw == null || raw.trim().isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        final result = <ChatMessage>[];
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            try {
              result.add(ChatMessage.fromMap(item, item['id'] ?? ''));
            } catch (itemError) {
              debugPrint('Error parsing cached ChatMessage: $itemError');
            }
          }
        }
        return result;
      }
    } catch (e) {
      debugPrint('LocalStorageService.getMessages error: $e');
    }
    return [];
  }

  // ---------------------------------------------------------------------------
  // Applications Persistence
  // ---------------------------------------------------------------------------

  Future<void> saveApplications(List<JobApplication> apps) async {
    try {
      if (!isInitialized) return;
      final list = apps.map((app) => app.toMap()).toList();
      await prefs.setString(keyApplications, jsonEncode(list));
    } catch (e) {
      debugPrint('LocalStorageService.saveApplications error: $e');
    }
  }

  List<JobApplication> getApplications() {
    try {
      if (!isInitialized) return [];
      final raw = _prefs?.getString(keyApplications);
      if (raw == null || raw.trim().isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        final result = <JobApplication>[];
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            try {
              result.add(JobApplication.fromMap(item, item['id'] ?? ''));
            } catch (itemError) {
              debugPrint('Error parsing cached JobApplication: $itemError');
            }
          }
        }
        return result;
      }
    } catch (e) {
      debugPrint('LocalStorageService.getApplications error: $e');
    }
    return [];
  }

  // ---------------------------------------------------------------------------
  // Clear All Data
  // ---------------------------------------------------------------------------

  Future<void> clearAll() async {
    try {
      if (isInitialized) {
        await prefs.clear();
      }
    } catch (e) {
      debugPrint('LocalStorageService.clearAll error: $e');
    }
  }
}
