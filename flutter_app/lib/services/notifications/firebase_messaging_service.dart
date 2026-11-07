// lib/services/notifications/firebase_messaging_service.dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../core/services/auth_service.dart';

/// Top-level background message handler for FCM
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM Background] Handling notification: ${message.messageId}');
}

/// Firebase Cloud Messaging Coordinator
/// Handles device token registration, notification permissions, and incoming alerts.
///
/// NOTE ON SPARK ZERO-BILLING COMPLIANCE:
/// Insecure client-side broadcasting of notifications across devices is strictly avoided.
/// Devices register their FCM push tokens to `users/{uid}` in Cloud Firestore.
/// Cross-device automated notifications require a trusted backend server or Cloud Functions,
/// which requires Blaze billing and is strictly excluded under the Spark free tier.
class FirebaseMessagingService {
  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications;

  FirebaseMessagingService({
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? localNotifications,
  })  : _messaging = messaging ?? FirebaseMessaging.instance,
        _localNotifications = localNotifications ?? FlutterLocalNotificationsPlugin();

  /// Initialize messaging handlers, notification channels, and token registration
  Future<void> initialize() async {
    try {
      // 1. Request user notification permissions
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      debugPrint('[FCM] Permission status: ${settings.authorizationStatus}');

      // 2. Set background message handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // 3. Register token to user profile
      final token = await getToken();
      if (token != null) {
        await syncTokenWithProfile(token);
      }

      // 4. Listen for token refreshes
      onTokenRefresh.listen((newToken) async {
        await syncTokenWithProfile(newToken);
      });

      // 5. Handle foreground notifications
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('[FCM Foreground] Received: ${message.notification?.title}');
        final notification = message.notification;
        if (notification != null) {
          _localNotifications.show(
            notification.hashCode,
            notification.title,
            notification.body,
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'paw_aid_rescue_alerts',
                'Rescue Alerts',
                importance: Importance.high,
                priority: Priority.high,
                icon: '@mipmap/ic_launcher',
              ),
            ),
          );
        }
      });
    } catch (e) {
      debugPrint('[FCM] Note: Messaging deferred ($e).');
    }
  }

  /// Synchronize FCM device token to current user's profile in Firestore
  Future<void> syncTokenWithProfile(String? token) async {
    if (token == null || token.isEmpty) return;
    try {
      await AuthService.updateFcmToken(token);
      debugPrint('[FCM] Device token registered to user profile.');
    } catch (e) {
      debugPrint('[FCM] Token sync deferred: $e');
    }
  }

  /// Retrieve active FCM device token
  Future<String?> getToken() async {
    try {
      return await _messaging.getToken();
    } catch (_) {
      return null;
    }
  }

  /// Listen to FCM token updates
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;
}
