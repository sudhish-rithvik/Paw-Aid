// lib/data/models/case_model.dart
import '../../core/constants/api_constants.dart';

class RescueCaseModel {
  final String id;
  final String reporterId;
  final String? reporterName;
  final String? reporterPhone;
  final String animalType;
  final String notes;
  final double latitude;
  final double longitude;
  final String address;
  final CaseStatus status;
  final PriorityLevel priorityLevel;
  final String? assignedNgoId;
  final String? assignedNgoName;
  final String? photoBase64;
  final String? imageUrl;
  final Map<String, dynamic>? aiAnalysis;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RescueCaseModel({
    required this.id,
    required this.reporterId,
    this.reporterName,
    this.reporterPhone,
    required this.animalType,
    required this.notes,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.status,
    required this.priorityLevel,
    this.assignedNgoId,
    this.assignedNgoName,
    this.photoBase64,
    this.imageUrl,
    this.aiAnalysis,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'reporterId': reporterId,
        'reporterName': reporterName,
        'reporterPhone': reporterPhone,
        'animalType': animalType,
        'notes': notes,
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
        'status': status.name,
        'priorityLevel': priorityLevel.name,
        'assignedNgoId': assignedNgoId,
        'assignedNgoName': assignedNgoName,
        'photoBase64': photoBase64,
        'imageUrl': imageUrl,
        'aiAnalysis': aiAnalysis,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory RescueCaseModel.fromMap(Map<String, dynamic> map, [String? docId]) {
    final ai = map['aiAnalysis'] as Map<String, dynamic>? ?? map['ai_analysis'] as Map<String, dynamic>?;
    final latNum = map['latitude'] ?? map['lat'] ?? ai?['latitude'] ?? 13.0827;
    final lngNum = map['longitude'] ?? map['lng'] ?? ai?['longitude'] ?? 80.2707;
    final sevStr = (map['priorityLevel'] ?? map['priority_level'] ?? map['severity'] ?? ai?['severity'] ?? 'medium').toString().toLowerCase();
    return RescueCaseModel(
        id: docId ?? map['id'] ?? map['case_id'] ?? map['reportId'] ?? '',
        reporterId: map['reporterId'] ?? map['reporter_id'] ?? map['citizenId'] ?? map['userId'] ?? '',
        reporterName: map['reporterName'] ?? map['reporter_name'] ?? map['citizenName'] ?? ai?['citizenName'],
        reporterPhone: map['reporterPhone'] ?? map['reporter_phone'] ?? map['citizenPhone'] ?? ai?['citizenPhone'],
        animalType: map['animalType'] ?? map['animal'] ?? ai?['animal'] ?? 'Dog',
        notes: map['notes'] ?? map['injuryDescription'] ?? map['animalDescription'] ?? ai?['injury'] ?? ai?['animalDescription'] ?? '',
        latitude: (latNum as num).toDouble(),
        longitude: (lngNum as num).toDouble(),
        address: map['address'] ?? ai?['address'] ?? 'Chennai, Tamil Nadu',
        status: CaseStatus.fromString(map['status']?.toString() ?? ai?['status']?.toString() ?? 'pending'),
        priorityLevel: PriorityLevel.values.firstWhere(
          (p) => p.name.toLowerCase() == sevStr || sevStr.contains(p.name.toLowerCase()),
          orElse: () => PriorityLevel.medium,
        ),
        assignedNgoId: map['assignedNgoId'] ?? map['assigned_ngo_id'] ?? ai?['assignedNgoId'],
        assignedNgoName: map['assignedNgoName'] ?? map['ngo_name'] ?? ai?['assignedNgoName'],
        photoBase64: map['photoBase64'],
        imageUrl: (map['photoReference'] != null && map['photoReference'].toString().startsWith('http'))
            ? map['photoReference'].toString()
            : (map['photoBase64'] ?? map['imageUrl'] ?? map['image_path'] ?? map['photoReference']),
        aiAnalysis: ai,
        createdAt: map['createdAt'] != null
            ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
            : DateTime.now(),
        updatedAt: map['updatedAt'] != null
            ? DateTime.tryParse(map['updatedAt'].toString()) ?? DateTime.now()
            : DateTime.now(),
      );
  }
}
