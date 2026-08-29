import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class FirebaseService {
  static bool _isInitialized = false;

  static bool get isInitialized => _isInitialized;

  /// Initializes Firebase and configures Cloud Firestore offline persistence.
  /// Safely catches platform/initialization errors in headless or offline environments.
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      _isInitialized = true;

      // Enable Cloud Firestore offline persistence and unlimited cache size
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('FirebaseService: Operating in local/offline fallback mode ($e)');
      }
      _isInitialized = false;
    }
  }
}
