// lib/data/repositories/assignment_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/firebase/firebase_constants.dart';
import '../models/assignment_model.dart';
import '../models/report_model.dart';

abstract class AssignmentRepository {
  Future<AssignmentModel> createAssignment(AssignmentModel assignment);
  Future<AssignmentModel?> getAssignment(String assignmentId);
  Stream<List<AssignmentModel>> streamAssignmentsForNgo(String ngoId);
  Future<List<AssignmentModel>> getAssignmentsForReport(String reportId);
  Future<void> acceptAssignment(String assignmentId, {String? notes, int? etaMinutes, String? actorId});
  Future<void> rejectAssignment(String assignmentId, String reason, {String? actorId});
}

class FirestoreAssignmentRepository implements AssignmentRepository {
  final FirebaseFirestore _firestore;

  FirestoreAssignmentRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _assignmentsRef =>
      _firestore.collection(FirebaseConstants.colAssignments);

  @override
  Future<AssignmentModel> createAssignment(AssignmentModel assignment) async {
    try {
      final map = assignment.toMap();
      map['createdAt'] = FieldValue.serverTimestamp();
      map['updatedAt'] = FieldValue.serverTimestamp();

      await _assignmentsRef.doc(assignment.assignmentId).set(map);
      return assignment;
    } catch (e) {
      throw AppFirestoreException('Failed to create assignment: $e');
    }
  }

  @override
  Future<AssignmentModel?> getAssignment(String assignmentId) async {
    try {
      final doc = await _assignmentsRef.doc(assignmentId).get();
      if (!doc.exists || doc.data() == null) return null;
      return AssignmentModel.fromMap(doc.data()!, doc.id);
    } catch (e) {
      throw AppFirestoreException('Failed to get assignment: $e');
    }
  }

  @override
  Stream<List<AssignmentModel>> streamAssignmentsForNgo(String ngoId) {
    return _assignmentsRef
        .where('ngoId', isEqualTo: ngoId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((d) => AssignmentModel.fromMap(d.data(), d.id)).toList());
  }

  @override
  Future<List<AssignmentModel>> getAssignmentsForReport(String reportId) async {
    try {
      final query = await _assignmentsRef
          .where('reportId', isEqualTo: reportId)
          .orderBy('createdAt', descending: true)
          .get();

      return query.docs.map((d) => AssignmentModel.fromMap(d.data(), d.id)).toList();
    } catch (e) {
      throw AppFirestoreException('Failed to query report assignments: $e');
    }
  }

  @override
  Future<void> acceptAssignment(
    String assignmentId, {
    String? notes,
    int? etaMinutes,
    String? actorId,
  }) async {
    try {
      final assignment = await getAssignment(assignmentId);
      if (assignment == null) {
        throw const AppFirestoreException('Assignment record not found');
      }

      final batch = _firestore.batch();
      final assignDoc = _assignmentsRef.doc(assignmentId);
      batch.update(assignDoc, {
        'status': AssignmentStatus.accepted.code,
        if (etaMinutes != null) 'etaMinutes': etaMinutes,
        if (notes != null) 'notes': notes,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update report status to ACCEPTED
      final reportDoc = _firestore.collection(FirebaseConstants.colReports).doc(assignment.reportId);
      final legacyDoc = _firestore.collection(FirebaseConstants.colRescueCases).doc(assignment.reportId);
      final updateData = {
        'reportStatus': ReportStatus.accepted.code,
        'status': ReportStatus.accepted.toCaseStatus().name,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      batch.update(reportDoc, updateData);
      batch.update(legacyDoc, updateData);

      // Append to status history
      final historyRef = reportDoc.collection(FirebaseConstants.subcolStatusHistory).doc();
      batch.set(historyRef, {
        'historyId': historyRef.id,
        'reportId': assignment.reportId,
        'previousStatus': ReportStatus.assigned.code,
        'newStatus': ReportStatus.accepted.code,
        'actorId': actorId ?? assignment.ngoId,
        'actorRole': 'ngo_staff',
        'notes': notes ?? 'Assignment accepted by ${assignment.ngoName}',
        'timestamp': FieldValue.serverTimestamp(),
      });

      await batch.commit();
    } catch (e) {
      throw AppFirestoreException('Failed to accept rescue assignment: $e');
    }
  }

  @override
  Future<void> rejectAssignment(
    String assignmentId,
    String reason, {
    String? actorId,
  }) async {
    try {
      final assignment = await getAssignment(assignmentId);
      if (assignment == null) {
        throw const AppFirestoreException('Assignment record not found');
      }

      final batch = _firestore.batch();
      final assignDoc = _assignmentsRef.doc(assignmentId);
      batch.update(assignDoc, {
        'status': AssignmentStatus.rejected.code,
        'rejectionReason': reason,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Revert report status back to UNDER_REVIEW so other NGOs or admins can re-assign
      final reportDoc = _firestore.collection(FirebaseConstants.colReports).doc(assignment.reportId);
      final legacyDoc = _firestore.collection(FirebaseConstants.colRescueCases).doc(assignment.reportId);
      final updateData = {
        'assignedNgoId': null,
        'assigned_ngo_id': null,
        'assignedNgoName': null,
        'ngo_name': null,
        'reportStatus': ReportStatus.underReview.code,
        'status': ReportStatus.underReview.toCaseStatus().name,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      batch.update(reportDoc, updateData);
      batch.update(legacyDoc, updateData);

      // Append to status history
      final historyRef = reportDoc.collection(FirebaseConstants.subcolStatusHistory).doc();
      batch.set(historyRef, {
        'historyId': historyRef.id,
        'reportId': assignment.reportId,
        'previousStatus': ReportStatus.assigned.code,
        'newStatus': ReportStatus.underReview.code,
        'actorId': actorId ?? assignment.ngoId,
        'actorRole': 'ngo_staff',
        'notes': 'Assignment declined: $reason. Reverted to rescue queue.',
        'timestamp': FieldValue.serverTimestamp(),
      });

      await batch.commit();
    } catch (e) {
      throw AppFirestoreException('Failed to decline rescue assignment: $e');
    }
  }
}
