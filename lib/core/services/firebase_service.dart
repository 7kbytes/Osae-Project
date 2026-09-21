import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class FirebaseService {
  static bool _isInitialized = false;
  static Object? _initError;

  static bool get isInitialized => _isInitialized;

  /// The error from the last failed [initialize] call, if any.
  static Object? get initError => _initError;

  /// Initializes Firebase and configures Cloud Firestore offline persistence.
  ///
  /// Never throws: on failure [isInitialized] stays false and [initError] is
  /// set so the caller can decide whether to show an error (release builds) or
  /// continue in local mode (tests, demo).
  static Future<void> initialize({FirebaseOptions? options}) async {
    if (_isInitialized) return;

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: options);
      }
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
      _isInitialized = true;
      _initError = null;
    } catch (e) {
      _initError = e;
      _isInitialized = false;
      debugPrint('FirebaseService: initialization failed ($e)');
    }
  }
}
