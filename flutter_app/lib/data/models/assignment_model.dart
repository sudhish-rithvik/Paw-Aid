// lib/data/models/assignment_model.dart

enum AssignmentStatus {
  assigned('ASSIGNED'),
  accepted('ACCEPTED'),
  rejected('REJECTED'),
  completed('COMPLETED');

  final String code;
  const AssignmentStatus(this.code);

  static AssignmentStatus fromString(String? val) {
    if (val == null) return AssignmentStatus.assigned;
    return AssignmentStatus.values.firstWhere(
      (e) => e.code.toUpperCase() == val.toUpperCase() || e.name.toLowerCase() == val.toLowerCase(),
      orElse: () => AssignmentStatus.assigned,
    );
  }
}

class AssignmentModel {
  final String assignmentId;
  final String reportId;
  final String ngoId;
  final String ngoName;
  final AssignmentStatus status;
  final String? assignedBy;
  final int? etaMinutes;
  final String? notes;
  final String? rejectionReason;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const AssignmentModel({
    required this.assignmentId,
    required this.reportId,
    required this.ngoId,
    required this.ngoName,
    this.status = AssignmentStatus.assigned,
    this.assignedBy,
    this.etaMinutes,
    this.notes,
    this.rejectionReason,
    required this.createdAt,
    this.updatedAt,
  });

  String get id => assignmentId;

  Map<String, dynamic> toMap() => {
        'assignmentId': assignmentId,
        'id': assignmentId,
        'reportId': reportId,
        'ngoId': ngoId,
        'ngoName': ngoName,
        'status': status.code,
        'assignedBy': assignedBy,
        'etaMinutes': etaMinutes,
        'notes': notes,
        'rejectionReason': rejectionReason,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': (updatedAt ?? createdAt).toUtc().toIso8601String(),
      };

  factory AssignmentModel.fromMap(Map<String, dynamic> map, [String? docId]) {
    final effectiveId = docId ?? map['assignmentId'] ?? map['id'] ?? '';
    final createdRaw = map['createdAt'] ?? map['created_at'];
    final updatedRaw = map['updatedAt'] ?? map['updated_at'];

    return AssignmentModel(
      assignmentId: effectiveId,
      reportId: map['reportId'] ?? map['report_id'] ?? '',
      ngoId: map['ngoId'] ?? map['ngo_id'] ?? '',
      ngoName: map['ngoName'] ?? map['ngo_name'] ?? 'NGO',
      status: AssignmentStatus.fromString(map['status'] as String?),
      assignedBy: map['assignedBy'] ?? map['assigned_by'],
      etaMinutes: (map['etaMinutes'] ?? map['eta_minutes'] as num?)?.toInt(),
      notes: map['notes'],
      rejectionReason: map['rejectionReason'] ?? map['rejection_reason'],
      createdAt: createdRaw != null ? DateTime.tryParse(createdRaw.toString()) ?? DateTime.now() : DateTime.now(),
      updatedAt: updatedRaw != null ? DateTime.tryParse(updatedRaw.toString()) : null,
    );
  }
}
