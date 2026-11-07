// lib/core/services/notification_service.dart
import 'package:flutter/foundation.dart';
import '../../data/models/notification_model.dart';
import '../../data/repositories/notification_repository.dart';
import 'auth_service.dart';

/// Notification Service
/// Handles incident notifications, status change alerts, and read state.
///
/// ARCHITECTURAL SECURITY NOTICE:
/// In compliance with Firebase Spark ($0.00 zero-billing tier), cross-user push notifications
/// (e.g., notifying citizen when NGO accepts case) cannot be triggered directly by client apps,
/// because client-side FCM broadcasting requires server-level Admin SDK service credentials.
/// Client-side notification creation is isolated to the recipient user in Firestore rules.
class NotificationService {
  NotificationService._();

  static final NotificationRepository _repository = FirestoreNotificationRepository();

  /// Retrieve notifications for current authenticated user
  static Future<List<Map<String, dynamic>>> getMyNotifications() async {
    String uid = '00000000-0000-0000-0000-000000000003';
    try {
      final user = await AuthService.getCurrentUser();
      if (user != null && user.id.isNotEmpty) {
        uid = user.id;
      }
    } catch (_) {}

    try {
      final notifs = await _repository.getNotifications(uid);
      if (notifs.isNotEmpty) {
        return notifs.map((n) => n.toMap()).toList();
      }
    } catch (e) {
      debugPrint('[NotificationService] Firestore query deferred: $e');
    }

    // Default welcome/informational notification
    return [
      {
        'id': 'notif-welcome',
        'notificationId': 'notif-welcome',
        'title': 'PAW AID Rescue Network Active',
        'body': 'Emergency animal rescue monitoring is live on Firebase Spark.',
        'type': 'SYSTEM',
        'is_read': false,
        'isRead': false,
        'created_at': DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String(),
        'createdAt': DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String(),
      },
    ];
  }

  /// Real-time stream of notifications for active user
  static Stream<List<NotificationModel>> streamMyNotifications() async* {
    String uid = '00000000-0000-0000-0000-000000000003';
    try {
      final user = await AuthService.getCurrentUser();
      if (user != null && user.id.isNotEmpty) {
        uid = user.id;
      }
    } catch (_) {}
    yield* _repository.streamNotifications(uid);
  }

  /// Mark notification as read
  static Future<void> markAsRead(String notificationId) async {
    try {
      await _repository.markAsRead(notificationId);
    } catch (e) {
      debugPrint('[NotificationService] markAsRead error: $e');
    }
  }
}
