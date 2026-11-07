// lib/data/repositories/notification_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/firebase/firebase_constants.dart';
import '../models/notification_model.dart';

abstract class NotificationRepository {
  Stream<List<NotificationModel>> streamNotifications(String userId);
  Future<List<NotificationModel>> getNotifications(String userId, {int limit = 30});
  Future<void> markAsRead(String notificationId);
  Future<void> createNotification(NotificationModel notification);
}

class FirestoreNotificationRepository implements NotificationRepository {
  final FirebaseFirestore _firestore;

  FirestoreNotificationRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _notificationsRef =>
      _firestore.collection(FirebaseConstants.colNotifications);

  @override
  Stream<List<NotificationModel>> streamNotifications(String userId) {
    return _notificationsRef
        .where('recipient_user_id', isEqualTo: userId)
        .orderBy('created_at', descending: true)
        .limit(30)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((d) => NotificationModel.fromMap(d.data(), d.id)).toList());
  }

  @override
  Future<List<NotificationModel>> getNotifications(String userId, {int limit = 30}) async {
    try {
      final snapshot = await _notificationsRef
          .where('recipient_user_id', isEqualTo: userId)
          .orderBy('created_at', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((d) => NotificationModel.fromMap(d.data(), d.id)).toList();
    } catch (e) {
      throw AppFirestoreException('Failed to query notifications: $e');
    }
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    try {
      await _notificationsRef.doc(notificationId).update({
        'is_read': true,
        'isRead': true,
      });
    } catch (e) {
      throw AppFirestoreException('Failed to mark notification as read: $e');
    }
  }

  @override
  Future<void> createNotification(NotificationModel notification) async {
    try {
      final map = notification.toMap();
      map['created_at'] = FieldValue.serverTimestamp();
      await _notificationsRef.doc(notification.id).set(map);
    } catch (e) {
      throw AppFirestoreException('Failed to dispatch notification: $e');
    }
  }
}
