// lib/core/firebase/firebase_initializer.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../../firebase_options.dart';
import 'firebase_constants.dart';

/// Firebase Spark Initialization Coordinator
/// Handles secure Firebase boot with offline-first Cloud Firestore persistence.
class FirebaseInitializer {
  FirebaseInitializer._();

  static bool _isInitialized = false;
  static bool get isInitialized => _isInitialized;

  /// Initialize Firebase Core and configure Firestore offline caching
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // 1. Initialize Firebase App:
      // On Android, Firebase.initializeApp() seamlessly uses the native configuration
      // from google-services.json generated during build.
      // If options are provided (or via dart-define), it initializes with options.
      if (defaultTargetPlatform == TargetPlatform.android) {
        try {
          await Firebase.initializeApp();
        } catch (_) {
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          );
        }
      } else {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      _isInitialized = true;
      debugPrint('[FirebaseInitializer] Firebase successfully initialized on Spark Tier (paw-aid-app).');

      // 2. Configure Cloud Firestore offline persistence settings
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: FirebaseConstants.firestoreCacheSizeBytes,
      );
      debugPrint('[FirebaseInitializer] Cloud Firestore offline persistence enabled.');
    } catch (e) {
      // Graceful fallback for offline demo execution before manual project credentials are bound
      debugPrint('[FirebaseInitializer] Note: Firebase initialization deferred ($e). Local demo mode active.');
    }
  }
}
