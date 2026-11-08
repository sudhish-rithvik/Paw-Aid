// lib/data/models/report_model.dart
import '../../core/constants/api_constants.dart';
import '../repositories/photo_storage_repository.dart';

/// Standard PAW-AID Emergency Report Statuses
enum ReportStatus {
  newReport('NEW', 'New Alert', '🚨'),
  underReview('UNDER_REVIEW', 'Under Review', '⏳'),
  assigned('ASSIGNED', 'Assigned to NGO', '📋'),
  accepted('ACCEPTED', 'NGO Accepted', '✅'),
  rescuerOnTheWay('RESCUER_ON_THE_WAY', 'Rescuer on the Way', '🚗'),
  animalRescued('ANIMAL_RESCUED', 'Animal Rescued', '🐾'),
  treatmentInProgress('TREATMENT_IN_PROGRESS', 'Treatment in Progress', '🏥'),
  resolved('RESOLVED', 'Resolved & Safe', '❤️'),
  rejected('REJECTED', 'Rejected', '❌');

  final String code;
  final String displayName;
  final String emoji;

  const ReportStatus(this.code, this.displayName, this.emoji);

  static ReportStatus fromString(String? val) {
    if (val == null || val.trim().isEmpty) return ReportStatus.newReport;
    final normalized = val.trim().replaceAll(' ', '_').replaceAll('-', '_').toUpperCase();

    // Check exact enum code match
    for (final s in ReportStatus.values) {
      if (s.code == normalized) return s;
    }

    // Map legacy application terminology
    final lower = val.trim().toLowerCase();
    return switch (lower) {
      'new' || 'reported' || 'open' => ReportStatus.newReport,
      'pending' || 'awaiting_ngo' || 'under_review' => ReportStatus.underReview,
      'assigned' => ReportStatus.assigned,
      'accepted' => ReportStatus.accepted,
      'dispatched' || 'on_the_way' || 'rescuer_on_the_way' => ReportStatus.rescuerOnTheWay,
      'animalpicked' || 'animal_picked' || 'picked_up' || 'rescued' => ReportStatus.animalRescued,
      'vettreatment' || 'vet_treatment' || 'treatment' || 'treatment_in_progress' || 'recovery' =>
        ReportStatus.treatmentInProgress,
      'completed' || 'closed' || 'resolved' => ReportStatus.resolved,
      'rejected' || 'cancelled' => ReportStatus.rejected,
      _ => ReportStatus.newReport,
    };
  }

  /// Convert to legacy CaseStatus for backward-compatible UI widgets
  CaseStatus toCaseStatus() {
    return switch (this) {
      ReportStatus.newReport || ReportStatus.underReview => CaseStatus.pending,
      ReportStatus.assigned || ReportStatus.accepted => CaseStatus.accepted,
      ReportStatus.rescuerOnTheWay => CaseStatus.dispatched,
      ReportStatus.animalRescued => CaseStatus.animalPicked,
      ReportStatus.treatmentInProgress => CaseStatus.vetTreatment,
      ReportStatus.resolved => CaseStatus.completed,
      ReportStatus.rejected => CaseStatus.closed,
    };
  }
}

/// Cloud Firestore Report Model
/// Represents an emergency animal rescue incident.
class ReportModel {
  final String reportId;
  final String citizenId;
  final String? citizenName;
  final String? citizenPhone;
  final String animalType;
  final String animalDescription;
  final String injuryCategory;
  final PriorityLevel severity;
  final double latitude;
  final double longitude;
  final String address;
  final String? photoReference;
  final PhotoUploadStatus photoUploadStatus;
  final String? assignedNgoId;
  final String? assignedNgoName;
  final ReportStatus reportStatus;
  final Map<String, dynamic>? aiAnalysis;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ReportModel({
    required this.reportId,
    required this.citizenId,
    this.citizenName,
    this.citizenPhone,
    required this.animalType,
    required this.animalDescription,
    this.injuryCategory = 'General Distress',
    required this.severity,
    required this.latitude,
    required this.longitude,
    required this.address,
    this.photoReference,
    this.photoUploadStatus = PhotoUploadStatus.localOnly,
    this.assignedNgoId,
    this.assignedNgoName,
    required this.reportStatus,
    this.aiAnalysis,
    required this.createdAt,
    required this.updatedAt,
  });

  String get id => reportId;
  String get notes => animalDescription;
  String? get reporterId => citizenId;
  String? get reporterName => citizenName;
  String? get reporterPhone => citizenPhone;
  CaseStatus get status => reportStatus.toCaseStatus();
  PriorityLevel get priorityLevel => severity;
  String? get imageUrl => photoReference;

  bool get isAssigned => assignedNgoId != null && assignedNgoId!.isNotEmpty;
  bool get isResolved => reportStatus == ReportStatus.resolved;

  Map<String, dynamic> toMap() => {
        'reportId': reportId,
        'id': reportId,
        'case_id': reportId,
        'citizenId': citizenId,
        'reporterId': citizenId,
        'citizenName': citizenName,
        'reporterName': citizenName,
        'citizenPhone': citizenPhone,
        'reporterPhone': citizenPhone,
        'animalType': animalType,
        'animal': animalType,
        'animalDescription': animalDescription,
        'injuryDescription': animalDescription,
        'notes': animalDescription,
        'injuryCategory': injuryCategory,
        'severity': severity.name.toUpperCase(),
        'priorityLevel': severity.name,
        'latitude': latitude,
        'lat': latitude,
        'longitude': longitude,
        'lng': longitude,
        'address': address,
        'photoReference': photoReference,
        'photoUploadStatus': photoUploadStatus.name,
        'assignedNgoId': assignedNgoId,
        'assigned_ngo_id': assignedNgoId,
        'assignedNgoName': assignedNgoName,
        'ngo_name': assignedNgoName,
        'reportStatus': reportStatus.code,
        'status': reportStatus.toCaseStatus().name,
        'aiAnalysis': aiAnalysis,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'created_at': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };

  factory ReportModel.fromMap(Map<String, dynamic> map, [String? docId]) {
    final effectiveId = docId ?? map['reportId'] ?? map['id'] ?? map['case_id'] ?? '';
    final citId = map['citizenId'] ?? map['reporterId'] ?? map['reporter_id'] ?? map['userId'] ?? '';
    final ai = map['aiAnalysis'] as Map<String, dynamic>? ?? map['ai_analysis'] as Map<String, dynamic>?;

    final aType = map['animalType'] ?? map['animal'] ?? ai?['animal'] ?? ai?['animalType'] ?? 'Dog';
    final desc = map['animalDescription'] ?? map['injuryDescription'] ?? map['notes'] ?? ai?['animalDescription'] ?? ai?['injury'] ?? ai?['description'] ?? '';
    final category = map['injuryCategory'] ?? ai?['injuryCategory'] ?? ai?['category'] ?? 'General Distress';

    // Parse severity
    final sevRaw = (map['severity'] ?? map['priorityLevel'] ?? map['priority_level'] ?? ai?['severity'] ?? 'medium')
        .toString()
        .toLowerCase();
    final sev = PriorityLevel.values.firstWhere(
      (p) => p.name.toLowerCase() == sevRaw || sevRaw.contains(p.name.toLowerCase()),
      orElse: () => PriorityLevel.medium,
    );

    // Parse status
    final statRaw = map['reportStatus'] ?? map['status'] ?? ai?['status'] ?? 'NEW';
    final rStatus = ReportStatus.fromString(statRaw.toString());

    // Parse upload status
    final upStatus = PhotoUploadStatus.fromString(map['photoUploadStatus'] as String?);

    final createdRaw = map['createdAt'] ?? map['created_at'];
    final updatedRaw = map['updatedAt'] ?? map['updated_at'];

    final latNum = map['latitude'] ?? map['lat'] ?? ai?['latitude'] ?? 13.0827;
    final lngNum = map['longitude'] ?? map['lng'] ?? ai?['longitude'] ?? 80.2707;

    return ReportModel(
      reportId: effectiveId,
      citizenId: citId,
      citizenName: map['citizenName'] ?? map['reporterName'] ?? map['reporter_name'] ?? ai?['citizenName'],
      citizenPhone: map['citizenPhone'] ?? map['reporterPhone'] ?? map['reporter_phone'] ?? ai?['citizenPhone'],
      animalType: aType,
      animalDescription: desc,
      injuryCategory: category,
      severity: sev,
      latitude: (latNum as num).toDouble(),
      longitude: (lngNum as num).toDouble(),
      address: map['address'] ?? ai?['address'] ?? 'Chennai, Tamil Nadu',
      photoReference: (map['photoReference'] != null && map['photoReference'].toString().startsWith('http'))
          ? map['photoReference'].toString()
          : (map['photoBase64'] ?? map['photoReference'] ?? map['imageUrl'] ?? map['image_path']),
      photoUploadStatus: upStatus,
      assignedNgoId: map['assignedNgoId'] ?? map['assigned_ngo_id'] ?? ai?['assignedNgoId'],
      assignedNgoName: map['assignedNgoName'] ?? map['ngo_name'] ?? ai?['assignedNgoName'],
      reportStatus: rStatus,
      aiAnalysis: ai,
      createdAt: createdRaw != null ? DateTime.tryParse(createdRaw.toString()) ?? DateTime.now() : DateTime.now(),
      updatedAt: updatedRaw != null ? DateTime.tryParse(updatedRaw.toString()) ?? DateTime.now() : DateTime.now(),
    );
  }

  ReportModel copyWith({
    String? reportId,
    String? citizenId,
    String? citizenName,
    String? citizenPhone,
    String? animalType,
    String? animalDescription,
    String? injuryCategory,
    PriorityLevel? severity,
    double? latitude,
    double? longitude,
    String? address,
    String? photoReference,
    PhotoUploadStatus? photoUploadStatus,
    String? assignedNgoId,
    String? assignedNgoName,
    ReportStatus? reportStatus,
    Map<String, dynamic>? aiAnalysis,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ReportModel(
      reportId: reportId ?? this.reportId,
      citizenId: citizenId ?? this.citizenId,
      citizenName: citizenName ?? this.citizenName,
      citizenPhone: citizenPhone ?? this.citizenPhone,
      animalType: animalType ?? this.animalType,
      animalDescription: animalDescription ?? this.animalDescription,
      injuryCategory: injuryCategory ?? this.injuryCategory,
      severity: severity ?? this.severity,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      photoReference: photoReference ?? this.photoReference,
      photoUploadStatus: photoUploadStatus ?? this.photoUploadStatus,
      assignedNgoId: assignedNgoId ?? this.assignedNgoId,
      assignedNgoName: assignedNgoName ?? this.assignedNgoName,
      reportStatus: reportStatus ?? this.reportStatus,
      aiAnalysis: aiAnalysis ?? this.aiAnalysis,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
