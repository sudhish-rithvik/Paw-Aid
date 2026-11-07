// lib/data/models/notification_model.dart

class NotificationModel {
  final String id;
  final String recipientUserId;
  final String title;
  final String body;
  final String type;
  final String? referenceId;
  final bool isRead;
  final DateTime createdAt;

  const NotificationModel({
    required this.id,
    required this.recipientUserId,
    required this.title,
    required this.body,
    required this.type,
    this.referenceId,
    this.isRead = false,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'recipient_user_id': recipientUserId,
        'title': title,
        'body': body,
        'type': type,
        'reference_id': referenceId,
        'is_read': isRead,
        'created_at': createdAt.toIso8601String(),
      };

  factory NotificationModel.fromMap(Map<String, dynamic> map, [String? docId]) => NotificationModel(
        id: docId ?? map['id'] ?? map['notificationId'] ?? '',
        recipientUserId: map['recipient_user_id'] ?? map['recipientUserId'] ?? '',
        title: map['title'] ?? '',
        body: map['body'] ?? '',
        type: map['type'] ?? 'STATUS_CHANGE',
        referenceId: map['reference_id'] ?? map['referenceId'],
        isRead: map['is_read'] ?? map['isRead'] ?? false,
        createdAt: map['created_at'] != null
            ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
            : DateTime.now(),
      );
}
