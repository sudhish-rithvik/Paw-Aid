// lib/data/repositories/case_repository.dart
import '../models/case_model.dart';
import '../models/report_model.dart';
import 'report_repository.dart';

abstract class CaseRepository {
  Future<RescueCaseModel> createReport(RescueCaseModel report);
  Future<RescueCaseModel?> getReport(String caseId);
  Stream<RescueCaseModel?> watchCase(String caseId);
  Future<List<RescueCaseModel>> getCitizenReports(String citizenId);
  Future<List<RescueCaseModel>> getRescueQueue({String? ngoId});
  Future<void> updateCaseStatus(String caseId, String status, {String? notes, String? photoBase64});
  Future<void> acceptCase(String caseId, String ngoId, String ngoName);
  Future<List<Map<String, dynamic>>> getCaseEvents(String caseId);
}

class FirestoreCaseRepository implements CaseRepository {
  final ReportRepository _reportRepository;

  FirestoreCaseRepository({ReportRepository? reportRepository})
      : _reportRepository = reportRepository ?? FirestoreReportRepository();

  @override
  Future<RescueCaseModel> createReport(RescueCaseModel report) async {
    final reportModel = ReportModel(
      reportId: report.id,
      citizenId: report.reporterId,
      citizenName: report.reporterName,
      citizenPhone: report.reporterPhone,
      animalType: report.animalType,
      animalDescription: report.notes,
      severity: report.priorityLevel,
      latitude: report.latitude,
      longitude: report.longitude,
      address: report.address,
      photoReference: report.imageUrl,
      assignedNgoId: report.assignedNgoId,
      assignedNgoName: report.assignedNgoName,
      reportStatus: ReportStatus.fromString(report.status.name),
      aiAnalysis: report.aiAnalysis,
      createdAt: report.createdAt,
      updatedAt: report.updatedAt,
    );

    await _reportRepository.createReport(reportModel);
    return report;
  }

  @override
  Future<RescueCaseModel?> getReport(String caseId) async {
    final report = await _reportRepository.getReport(caseId);
    if (report == null) return null;
    return RescueCaseModel.fromMap(report.toMap(), report.reportId);
  }

  @override
  Stream<RescueCaseModel?> watchCase(String caseId) {
    return _reportRepository.streamReport(caseId).map((report) {
      if (report == null) return null;
      return RescueCaseModel.fromMap(report.toMap(), report.reportId);
    });
  }

  @override
  Future<List<RescueCaseModel>> getCitizenReports(String citizenId) async {
    final reports = await _reportRepository.getCitizenReports(citizenId);
    return reports.map((r) => RescueCaseModel.fromMap(r.toMap(), r.reportId)).toList();
  }

  @override
  Future<List<RescueCaseModel>> getRescueQueue({String? ngoId}) async {
    final reports = await _reportRepository.getReportsPaginated();
    return reports.map((r) => RescueCaseModel.fromMap(r.toMap(), r.reportId)).toList();
  }

  @override
  Future<void> updateCaseStatus(String caseId, String status, {String? notes, String? photoBase64}) async {
    final rStatus = ReportStatus.fromString(status);
    await _reportRepository.updateReportStatus(
      caseId,
      rStatus,
      notes: notes,
      photoReference: photoBase64,
    );
  }

  @override
  Future<void> acceptCase(String caseId, String ngoId, String ngoName) async {
    await _reportRepository.assignReport(caseId, ngoId, ngoName);
  }

  @override
  Future<List<Map<String, dynamic>>> getCaseEvents(String caseId) async {
    // Return empty list or fetch from subcollection
    return [];
  }
}
