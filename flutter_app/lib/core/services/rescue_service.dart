// lib/core/services/rescue_service.dart
import 'package:flutter/foundation.dart';
import '../../data/models/report_model.dart';
import '../../data/repositories/report_repository.dart';
import 'report_service.dart';

/// Rescue Service
/// Orchestrates NGO rescue missions, stage transitions, and field evidence capture.
class RescueService {
  RescueService._();

  static final ReportRepository _reportRepository = FirestoreReportRepository();

  /// Accept an incoming animal distress report
  static Future<Map<String, dynamic>> acceptRescueReport(
    String reportId, {
    int etaMinutes = 20,
    String? notes,
  }) async {
    const ngoId = '11111111-1111-1111-1111-111111111111';
    const ngoName = 'Chennai Animal Rescue Foundation (CARF)';

    try {
      await _reportRepository.assignReport(
        reportId,
        ngoId,
        ngoName,
        assignedBy: 'ngo_staff',
      );
      await _reportRepository.updateReportStatus(
        reportId,
        ReportStatus.accepted,
        notes: notes ?? 'Accepted by $ngoName with ETA $etaMinutes mins',
        actorId: ngoId,
        actorRole: 'ngo_staff',
      );
    } catch (e) {
      debugPrint('[RescueService] Offline Firestore assignment deferred: $e');
    }

    final existing = await ReportService.getReport(reportId);
    existing['status'] = 'accepted';
    existing['reportStatus'] = 'ACCEPTED';
    existing['assigned_ngo_id'] = ngoId;
    existing['assignedNgoId'] = ngoId;
    existing['ngo_name'] = ngoName;
    existing['assignedNgoName'] = ngoName;
    if (notes != null) existing['notes'] = notes;
    return existing;
  }

  /// Update Rescue Progression Status (7-Stage Workflow) with optional photo evidence
  static Future<Map<String, dynamic>> updateRescueStatus(
    String reportId,
    String status, {
    List<int>? imageBytes,
    String? notes,
  }) async {
    final rStatus = ReportStatus.fromString(status);

    try {
      await _reportRepository.updateReportStatus(
        reportId,
        rStatus,
        notes: notes,
        actorId: '11111111-1111-1111-1111-111111111111',
        actorRole: 'ngo_staff',
      );
    } catch (e) {
      debugPrint('[RescueService] Offline Firestore status update deferred: $e');
    }

    final existing = await ReportService.getReport(reportId);
    existing['status'] = status.toLowerCase();
    existing['reportStatus'] = rStatus.code;
    if (notes != null && notes.isNotEmpty) {
      existing['notes'] = notes;
    }
    return existing;
  }
}
