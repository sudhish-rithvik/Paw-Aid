// lib/data/repositories/report_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/firebase/firebase_constants.dart';
import '../models/report_model.dart';
import '../models/status_history_model.dart';

abstract class ReportRepository {
  Future<ReportModel> createReport(ReportModel report);
  Future<ReportModel?> getReport(String reportId);
  Stream<ReportModel?> streamReport(String reportId);
  Stream<List<ReportModel>> streamCitizenReports(String citizenId);
  Future<List<ReportModel>> getCitizenReports(String citizenId, {int limit = 20, DocumentSnapshot? startAfter});
  Stream<List<ReportModel>> streamRescueQueue({String? ngoId});
  Future<List<ReportModel>> getReportsPaginated({int limit = 20, DocumentSnapshot? startAfter, String? status, String? severity});
  Future<void> updateReportStatus(String reportId, ReportStatus newStatus, {String? notes, String? actorId, String? actorRole, String? photoReference});
  Future<void> assignReport(String reportId, String ngoId, String ngoName, {String? assignedBy});
}

class FirestoreReportRepository implements ReportRepository {
  final FirebaseFirestore _firestore;

  FirestoreReportRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _reportsRef =>
      _firestore.collection(FirebaseConstants.colReports);

  @override
  Future<ReportModel> createReport(ReportModel report) async {
    try {
      final map = report.toMap();
      // Use server timestamp for reliable sorting
      map['createdAt'] = FieldValue.serverTimestamp();
      map['updatedAt'] = FieldValue.serverTimestamp();

      final batch = _firestore.batch();
      final reportDoc = _reportsRef.doc(report.reportId);
      batch.set(reportDoc, map);

      // Also mirror to legacy rescue_cases collection for uninterrupted existing screen support
      final legacyDoc = _firestore.collection(FirebaseConstants.colRescueCases).doc(report.reportId);
      batch.set(legacyDoc, map);

      // Atomically create initial status history entry
      final historyRef = reportDoc.collection(FirebaseConstants.subcolStatusHistory).doc();
      final initialHistory = StatusHistoryModel(
        historyId: historyRef.id,
        reportId: report.reportId,
        newStatus: report.reportStatus.code,
        actorId: report.citizenId,
        actorRole: 'citizen',
        notes: 'Report submitted by citizen',
        timestamp: DateTime.now(),
      );
      batch.set(historyRef, initialHistory.toMap());

      await batch.commit();
      return report;
    } catch (e) {
      throw AppFirestoreException('Failed to submit animal distress report: $e');
    }
  }

  @override
  Future<ReportModel?> getReport(String reportId) async {
    try {
      final doc = await _reportsRef.doc(reportId).get();
      if (doc.exists && doc.data() != null) {
        return ReportModel.fromMap(doc.data()!, doc.id);
      }
      // Check legacy fallback
      final legacy = await _firestore.collection(FirebaseConstants.colRescueCases).doc(reportId).get();
      if (legacy.exists && legacy.data() != null) {
        return ReportModel.fromMap(legacy.data()!, legacy.id);
      }
      return null;
    } catch (e) {
      throw AppFirestoreException('Failed to retrieve report: $e');
    }
  }

  @override
  Stream<ReportModel?> streamReport(String reportId) {
    return _reportsRef.doc(reportId).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) return null;
      return ReportModel.fromMap(snapshot.data()!, snapshot.id);
    });
  }

  @override
  Stream<List<ReportModel>> streamCitizenReports(String citizenId) {
    return _reportsRef
        .where('citizenId', isEqualTo: citizenId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((d) => ReportModel.fromMap(d.data(), d.id)).toList());
  }

  @override
  Future<List<ReportModel>> getCitizenReports(
    String citizenId, {
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _reportsRef
          .where('citizenId', isEqualTo: citizenId)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();
      return snapshot.docs.map((d) => ReportModel.fromMap(d.data(), d.id)).toList();
    } catch (e) {
      throw AppFirestoreException('Failed to query citizen reports: $e');
    }
  }

  @override
  Stream<List<ReportModel>> streamRescueQueue({String? ngoId}) {
    // Open cases awaiting rescue or currently active
    Query<Map<String, dynamic>> query = _reportsRef.where(
      'reportStatus',
      whereIn: [
        ReportStatus.newReport.code,
        ReportStatus.underReview.code,
        ReportStatus.assigned.code,
        ReportStatus.accepted.code,
        ReportStatus.rescuerOnTheWay.code,
        ReportStatus.treatmentInProgress.code,
      ],
    ).limit(50);

    return query.snapshots().map((snapshot) {
      var reports = snapshot.docs.map((d) => ReportModel.fromMap(d.data(), d.id)).toList();
      if (ngoId != null && ngoId.isNotEmpty) {
        reports = reports
            .where((r) => r.assignedNgoId == null || r.assignedNgoId == ngoId)
            .toList();
      }
      return reports;
    });
  }

  @override
  Future<List<ReportModel>> getReportsPaginated({
    int limit = 20,
    DocumentSnapshot? startAfter,
    String? status,
    String? severity,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _reportsRef.orderBy('createdAt', descending: true);

      if (status != null && status.isNotEmpty) {
        final rStatus = ReportStatus.fromString(status);
        query = query.where('reportStatus', isEqualTo: rStatus.code);
      }
      if (severity != null && severity.isNotEmpty) {
        query = query.where('severity', isEqualTo: severity.toUpperCase());
      }
      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      query = query.limit(limit);
      final snapshot = await query.get();
      return snapshot.docs.map((d) => ReportModel.fromMap(d.data(), d.id)).toList();
    } catch (e) {
      throw AppFirestoreException('Failed to query paginated reports: $e');
    }
  }

  @override
  Future<void> updateReportStatus(
    String reportId,
    ReportStatus newStatus, {
    String? notes,
    String? actorId,
    String? actorRole,
    String? photoReference,
  }) async {
    try {
      final batch = _firestore.batch();
      final reportDoc = _reportsRef.doc(reportId);
      final legacyDoc = _firestore.collection(FirebaseConstants.colRescueCases).doc(reportId);

      final updateMap = <String, dynamic>{
        'reportStatus': newStatus.code,
        'status': newStatus.toCaseStatus().name,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (notes != null && notes.isNotEmpty) {
        updateMap['animalDescription'] = notes;
        updateMap['notes'] = notes;
      }
      if (photoReference != null && photoReference.isNotEmpty) {
        updateMap['photoReference'] = photoReference;
      }

      batch.update(reportDoc, updateMap);
      batch.update(legacyDoc, updateMap);

      // Append to status history subcollection
      final historyRef = reportDoc.collection(FirebaseConstants.subcolStatusHistory).doc();
      final historyEntry = StatusHistoryModel(
        historyId: historyRef.id,
        reportId: reportId,
        newStatus: newStatus.code,
        actorId: actorId,
        actorRole: actorRole ?? 'ngo_staff',
        notes: notes,
        photoReference: photoReference,
        timestamp: DateTime.now(),
      );
      batch.set(historyRef, historyEntry.toMap());

      await batch.commit();
    } catch (e) {
      throw AppFirestoreException('Failed to update report status: $e');
    }
  }

  @override
  Future<void> assignReport(
    String reportId,
    String ngoId,
    String ngoName, {
    String? assignedBy,
  }) async {
    try {
      final batch = _firestore.batch();
      final reportDoc = _reportsRef.doc(reportId);
      final legacyDoc = _firestore.collection(FirebaseConstants.colRescueCases).doc(reportId);

      final updateMap = {
        'assignedNgoId': ngoId,
        'assigned_ngo_id': ngoId,
        'assignedNgoName': ngoName,
        'ngo_name': ngoName,
        'reportStatus': ReportStatus.assigned.code,
        'status': ReportStatus.assigned.toCaseStatus().name,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      batch.update(reportDoc, updateMap);
      batch.update(legacyDoc, updateMap);

      // Create assignment record in assignments collection
      final assignmentRef = _firestore.collection(FirebaseConstants.colAssignments).doc();
      batch.set(assignmentRef, {
        'assignmentId': assignmentRef.id,
        'reportId': reportId,
        'ngoId': ngoId,
        'ngoName': ngoName,
        'status': 'ASSIGNED',
        'assignedBy': assignedBy ?? 'admin',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Append to status history
      final historyRef = reportDoc.collection(FirebaseConstants.subcolStatusHistory).doc();
      batch.set(historyRef, {
        'historyId': historyRef.id,
        'reportId': reportId,
        'newStatus': ReportStatus.assigned.code,
        'actorId': assignedBy ?? 'admin',
        'actorRole': 'admin',
        'notes': 'Report assigned to $ngoName',
        'timestamp': FieldValue.serverTimestamp(),
      });

      await batch.commit();
    } catch (e) {
      throw AppFirestoreException('Failed to assign report to NGO: $e');
    }
  }
}
