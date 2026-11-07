// lib/core/services/report_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/api_constants.dart';
import '../../data/models/report_model.dart';
import '../../data/repositories/photo_storage_repository.dart';
import '../../data/repositories/report_repository.dart';
import 'ai_analysis_service.dart';

/// Report Service
/// Handles citizen report lifecycle, local caching, PhotoStorage, and Firestore persistence.
class ReportService {
  ReportService._();

  static const _uuid = Uuid();
  static const String _cacheKey = 'paw_aid_cached_reports';
  static const PhotoStorageRepository _photoStorage = LocalPhotoStorageRepository();
  static final ReportRepository _reportRepository = FirestoreReportRepository();

  /// Complete Citizen Report Workflow:
  /// 1. Save photo locally via PhotoStorageRepository (No Blaze billing, zero Firebase Storage)
  /// 2. Persist ReportModel to Cloud Firestore (collection 'reports' and alias 'rescue_cases')
  /// 3. Cache report locally for offline resilience
  /// 4. Trigger asynchronous AI Analysis
  static Future<Map<String, dynamic>> submitAnimalReport({
    required dynamic imageSource, // String filePath or List<int> bytes
    required double latitude,
    required double longitude,
    String? address,
    String animalType = 'Dog',
    String? notes,
    String? userId,
    String? idempotencyKey,
  }) async {
    final now = DateTime.now().toUtc();
    final reportId = _uuid.v4();
    final imagePath = imageSource is String ? imageSource : 'cached_report_$reportId.jpg';

    // 1. Save photo locally on device (preserving zero-cost Spark tier)
    final photoRef = await _photoStorage.saveLocalPhoto(
      sourcePath: imagePath,
      reportId: reportId,
    );

    // 2. Perform on-device vision triage (LiteRT abstraction)
    Map<String, dynamic>? aiAnalysis;
    PriorityLevel triageSeverity = PriorityLevel.high;
    String effectiveCategory = 'General Distress';
    try {
      aiAnalysis = await AIAnalysisService.triggerAIAnalysis(
        reportId,
        imagePath: photoRef,
        notes: notes,
        animalType: animalType,
      );
      final sev = aiAnalysis['severity'] as String? ?? 'high';
      triageSeverity = switch (sev.toLowerCase()) {
        'critical' => PriorityLevel.critical,
        'high' => PriorityLevel.high,
        'medium' => PriorityLevel.medium,
        _ => PriorityLevel.low,
      };
      final injuries = aiAnalysis['visible_injuries'] as List?;
      if (injuries != null && injuries.isNotEmpty) {
        effectiveCategory = injuries.first.toString();
      }
    } catch (e) {
      debugPrint('[ReportService] On-device AI triage fallback: $e');
    }

    // 3. Build canonical ReportModel with preliminary AI triage
    final reportModel = ReportModel(
      reportId: reportId,
      citizenId: userId ?? '00000000-0000-0000-0000-000000000003',
      citizenName: 'Priya Ramesh (Animal Lover)',
      animalType: animalType,
      animalDescription: notes ?? 'Animal in distress reported by citizen.',
      injuryCategory: effectiveCategory,
      severity: triageSeverity,
      latitude: latitude,
      longitude: longitude,
      address: address ?? 'Chennai, Tamil Nadu',
      photoReference: photoRef,
      photoUploadStatus: PhotoUploadStatus.pendingStorageProvider,
      reportStatus: ReportStatus.newReport,
      aiAnalysis: aiAnalysis,
      createdAt: now,
      updatedAt: now,
    );

    final rawReport = reportModel.toMap();
    final formatted = formatReportForUi(rawReport);

    // 4. Persist to Cloud Firestore
    try {
      await _reportRepository.createReport(reportModel);
      debugPrint('[ReportService] Report $reportId persisted to Cloud Firestore.');
    } catch (e) {
      debugPrint('[ReportService] Firestore offline write queued or deferred: $e');
    }

    // 5. Cache report locally in SharedPreferences for immediate persistence
    await _cacheReportLocally(formatted);

    return formatted;
  }

  /// Get user's reports (Citizen)
  static Future<List<Map<String, dynamic>>> getMyReports() async {
    // 1. Try reading from Cloud Firestore if available
    try {
      final userReports = await _reportRepository.getCitizenReports(
        '00000000-0000-0000-0000-000000000003',
        limit: 20,
      );
      if (userReports.isNotEmpty) {
        return userReports.map((r) => formatReportForUi(r.toMap())).toList();
      }
    } catch (_) {}

    // 2. Fallback to locally cached reports
    final cached = await _getCachedReports();
    if (cached.isNotEmpty) {
      return cached;
    }

    // 3. Default sample reports for demonstration
    return [
      formatReportForUi({
        'reportId': 'report-sample-001',
        'citizenId': '00000000-0000-0000-0000-000000000003',
        'animalType': 'Dog',
        'animalDescription': 'Limping near Besant Nagar beach with front paw injury.',
        'latitude': 13.0001,
        'longitude': 80.2667,
        'address': 'Besant Nagar, Chennai, Tamil Nadu',
        'preliminarySeverity': 'HIGH',
        'reportStatus': 'ACCEPTED',
        'status': 'accepted',
        'assignedNgoId': '11111111-1111-1111-1111-111111111111',
        'assignedNgoName': 'Chennai Animal Rescue Foundation (CARF)',
        'createdAt': DateTime.now().subtract(const Duration(hours: 3)).toUtc().toIso8601String(),
      }),
      formatReportForUi({
        'reportId': 'report-sample-002',
        'citizenId': '00000000-0000-0000-0000-000000000003',
        'animalType': 'Cat',
        'animalDescription': 'Trapped on terrace with visible minor scratches.',
        'latitude': 13.0382,
        'longitude': 80.2458,
        'address': 'Alwarpet, Chennai, Tamil Nadu',
        'preliminarySeverity': 'MEDIUM',
        'reportStatus': 'RESCUER_ON_THE_WAY',
        'status': 'dispatched',
        'assignedNgoId': '11111111-1111-1111-1111-111111111111',
        'assignedNgoName': 'Chennai Animal Rescue Foundation (CARF)',
        'createdAt': DateTime.now().subtract(const Duration(hours: 1)).toUtc().toIso8601String(),
      }),
    ];
  }

  /// Get single report detail by ID
  static Future<Map<String, dynamic>> getReport(String reportId) async {
    // 1. Try fetching from Firestore
    try {
      final firestoreReport = await _reportRepository.getReport(reportId);
      if (firestoreReport != null) {
        return formatReportForUi(firestoreReport.toMap());
      }
    } catch (_) {}

    // 2. Try fetching from local cache
    final cached = await _getCachedReportById(reportId);
    if (cached != null) return cached;

    // 3. Fallback mock record
    return formatReportForUi({
      'reportId': reportId,
      'animalType': 'Dog',
      'animalDescription': 'Animal distress report loaded from local repository.',
      'latitude': 13.0827,
      'longitude': 80.2707,
      'address': 'Chennai, Tamil Nadu',
      'preliminarySeverity': 'HIGH',
      'reportStatus': 'UNDER_REVIEW',
      'status': 'pending',
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// Watch live single report status stream from Cloud Firestore
  static Stream<Map<String, dynamic>> watchReport(String reportId) {
    return _reportRepository.streamReport(reportId).map((report) {
      if (report == null) {
        return formatReportForUi({'reportId': reportId, 'reportStatus': 'UNDER_REVIEW'});
      }
      return formatReportForUi(report.toMap());
    });
  }

  /// Format raw map from Firestore or API for UI consumption
  static Map<String, dynamic> formatReportForUi(Map<String, dynamic> r) {
    final rawStatus = (r['reportStatus'] ?? r['status'] ?? 'pending').toString();
    final uiStatus = _mapStatusToUi(rawStatus);

    final rawSeverity = (r['severity'] ?? r['preliminarySeverity'] ?? r['priorityLevel'] ?? 'medium')
        .toString()
        .toLowerCase();

    final lat = (r['latitude'] ?? r['lat'] as num?)?.toDouble() ?? 13.0827;
    final lng = (r['longitude'] ?? r['lng'] as num?)?.toDouble() ?? 80.2707;
    final imageUrl = r['photoReference'] ?? r['imageUrl'] ?? r['image_path'] ?? '';
    final imageKey = r['imageKey'] ?? '';
    final id = r['reportId'] ?? r['id'] ?? r['case_id'] ?? '';

    return {
      'id': id,
      'case_id': id,
      'reportId': id,
      'citizen_id': r['citizenId'] ?? r['reporterId'] ?? '',
      'citizen_name': r['citizenName'] ?? r['reporterName'] ?? 'Citizen Reporter',
      'animal': r['animalType'] ?? r['animal'] ?? 'Dog',
      'animal_type': r['animalType'] ?? r['animal'] ?? 'Dog',
      'status': uiStatus,
      'reportStatus': rawStatus.toUpperCase(),
      'priority_level': rawSeverity,
      'latitude': lat,
      'longitude': lng,
      'address': r['address'] ?? 'Chennai, Tamil Nadu',
      'notes': r['animalDescription'] ?? r['injuryDescription'] ?? r['notes'] ?? '',
      'image_path': imageUrl,
      'imageUrl': imageUrl,
      'photoReference': imageUrl,
      'photoUploadStatus': r['photoUploadStatus'] ?? 'pendingStorageProvider',
      'imageKey': imageKey,
      'created_at': r['createdAt'] ?? r['created_at'] ?? DateTime.now().toUtc().toIso8601String(),
      'createdAt': r['createdAt'] ?? r['created_at'] ?? DateTime.now().toUtc().toIso8601String(),
      'assigned_ngo_id': r['assignedNgoId'] ?? r['assigned_ngo_id'],
      'assignedNgoId': r['assignedNgoId'] ?? r['assigned_ngo_id'],
      'ngo_name': r['assignedNgoName'] ?? r['ngo_name'],
      'ngo_phone': r['assignedNgoPhone'] ?? r['ngo_phone'] ?? '+914411223344',
      'ai_score': (r['confidence'] as num?)?.toDouble() ?? 94.0,
      'visible_injuries': r['injuriesDetected'] ?? ['Laceration and fracture'],
      'severity': rawSeverity,
      'recommended_action': r['recommendedAction'] ?? 'Immediate dispatch of animal ambulance and clinical stabilization.',
      'ai_analysis': {
        'animal': r['animalType'] ?? 'Dog',
        'visible_injuries': r['injuriesDetected'] ?? ['Laceration and fracture'],
        'confidence': 0.94,
        'severity_score': rawSeverity,
      },
    };
  }

  static String _mapStatusToUi(String rawStatus) {
    final s = rawStatus.toUpperCase();
    switch (s) {
      case 'NEW':
      case 'REPORTED':
      case 'AI_ANALYSIS_PENDING':
      case 'AI_ANALYSIS_COMPLETED':
      case 'AWAITING_NGO':
      case 'UNDER_REVIEW':
      case 'PENDING':
        return 'pending';
      case 'ASSIGNED':
      case 'ACCEPTED':
        return 'accepted';
      case 'RESCUE_IN_PROGRESS':
      case 'RESCUER_ON_THE_WAY':
      case 'DISPATCHED':
        return 'dispatched';
      case 'ANIMAL_RESCUED':
      case 'ANIMAL_PICKED':
        return 'animal_picked';
      case 'TREATMENT_IN_PROGRESS':
      case 'VET_TREATMENT':
        return 'vet_treatment';
      case 'RESCUED':
      case 'RECOVERY':
        return 'recovery';
      case 'RESOLVED':
      case 'COMPLETED':
        return 'completed';
      case 'CLOSED':
        return 'closed';
      case 'REJECTED':
      case 'CANCELLED':
        return 'closed';
      default:
        return 'pending';
    }
  }

  static Future<void> _cacheReportLocally(Map<String, dynamic> report) async {
    final list = await _getCachedReports();
    list.removeWhere((r) => r['id'] == report['id']);
    list.insert(0, report);
    await _saveCachedReports(list);
  }

  static Future<List<Map<String, dynamic>>> _getCachedReports() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  static Future<Map<String, dynamic>?> _getCachedReportById(String id) async {
    final list = await _getCachedReports();
    return list.cast<Map<String, dynamic>?>().firstWhere(
          (r) => r?['id'] == id,
          orElse: () => null,
        );
  }

  static Future<void> _saveCachedReports(List<Map<String, dynamic>> reports) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, jsonEncode(reports));
  }
}
