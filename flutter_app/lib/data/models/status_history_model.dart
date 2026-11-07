// lib/data/models/status_history_model.dart

class StatusHistoryModel {
  final String historyId;
  final String reportId;
  final String? previousStatus;
  final String newStatus;
  final String? actorId;
  final String? actorRole;
  final String? notes;
  final String? photoReference;
  final DateTime timestamp;

  const StatusHistoryModel({
    required this.historyId,
    required this.reportId,
    this.previousStatus,
    required this.newStatus,
    this.actorId,
    this.actorRole,
    this.notes,
    this.photoReference,
    required this.timestamp,
  });

  String get id => historyId;

  Map<String, dynamic> toMap() => {
        'historyId': historyId,
        'id': historyId,
        'reportId': reportId,
        'previousStatus': previousStatus,
        'newStatus': newStatus,
        'actorId': actorId,
        'actorRole': actorRole,
        'notes': notes,
        'photoReference': photoReference,
        'timestamp': timestamp.toUtc().toIso8601String(),
      };

  factory StatusHistoryModel.fromMap(Map<String, dynamic> map, [String? docId]) {
    final effectiveId = docId ?? map['historyId'] ?? map['id'] ?? '';
    final timeRaw = map['timestamp'] ?? map['created_at'];

    return StatusHistoryModel(
      historyId: effectiveId,
      reportId: map['reportId'] ?? map['report_id'] ?? '',
      previousStatus: map['previousStatus'] ?? map['previous_status'],
      newStatus: map['newStatus'] ?? map['status'] ?? 'NEW',
      actorId: map['actorId'] ?? map['actor_id'],
      actorRole: map['actorRole'] ?? map['actor_role'],
      notes: map['notes'],
      photoReference: map['photoReference'] ?? map['photo_reference'],
      timestamp: timeRaw != null ? DateTime.tryParse(timeRaw.toString()) ?? DateTime.now() : DateTime.now(),
    );
  }
}
