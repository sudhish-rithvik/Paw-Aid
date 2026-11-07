// lib/services/firestore/firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/firebase/firebase_constants.dart';
import '../../data/models/case_model.dart';
import '../../data/models/ngo_model.dart';
import '../../data/models/notification_model.dart';
import '../../data/models/user_model.dart';

/// Cloud Firestore Service (Spark Plan Compliant)
/// Handles document persistence, compound queries, and real-time reactive snapshots.
class FirestoreService {
  final FirebaseFirestore _firestore;

  FirestoreService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // ─── Users ─────────────────────────────────────────────────────────────────

  Future<UserModel?> getUser(String userId) async {
    try {
      final doc = await _firestore.collection(FirebaseConstants.colUsers).doc(userId).get();
      if (!doc.exists || doc.data() == null) return null;
      return UserModel.fromMap(doc.data()!, doc.id);
    } catch (e) {
      throw AppFirestoreException('Failed to get user: $e');
    }
  }

  Future<void> setUser(UserModel user) async {
    try {
      await _firestore
          .collection(FirebaseConstants.colUsers)
          .doc(user.id)
          .set(user.toMap(), SetOptions(merge: true));
    } catch (e) {
      throw AppFirestoreException('Failed to set user: $e');
    }
  }

  Future<void> updateUserFcmToken(String userId, String token) async {
    try {
      await _firestore.collection(FirebaseConstants.colUsers).doc(userId).update({
        'fcm_token': token,
        'updated_at': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  // ─── Rescue Cases ──────────────────────────────────────────────────────────

  Future<void> createRescueCase(RescueCaseModel report) async {
    try {
      final map = report.toMap();
      // Ensure image payload respects Spark Firestore 1 MiB document limit
      if (report.photoBase64 != null &&
          report.photoBase64!.length > FirebaseConstants.maxCompressedImageSizeBytes * 2) {
        throw const AppFirestoreException('Compressed image exceeds Spark single-document limit');
      }

      await _firestore.collection(FirebaseConstants.colRescueCases).doc(report.id).set(map);

      // Add initial audit event
      await _firestore
          .collection(FirebaseConstants.colRescueCases)
          .doc(report.id)
          .collection(FirebaseConstants.subcolEvents)
          .add({
        'eventType': 'REPORT_CREATED',
        'status': report.status.name,
        'actorId': report.reporterId,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw AppFirestoreException('Failed to create rescue case: $e');
    }
  }

  Future<RescueCaseModel?> getRescueCase(String caseId) async {
    try {
      final doc = await _firestore.collection(FirebaseConstants.colRescueCases).doc(caseId).get();
      if (!doc.exists || doc.data() == null) return null;
      return RescueCaseModel.fromMap(doc.data()!, doc.id);
    } catch (e) {
      throw AppFirestoreException('Failed to get rescue case: $e');
    }
  }

  /// Real-time single case listener
  Stream<RescueCaseModel> watchRescueCase(String caseId) {
    return _firestore
        .collection(FirebaseConstants.colRescueCases)
        .doc(caseId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        throw const AppFirestoreException('Case does not exist');
      }
      return RescueCaseModel.fromMap(snapshot.data()!, snapshot.id);
    });
  }

  /// Query citizen's personal submitted reports
  Future<List<RescueCaseModel>> getCitizenCases(String citizenId) async {
    try {
      final query = await _firestore
          .collection(FirebaseConstants.colRescueCases)
          .where('reporterId', isEqualTo: citizenId)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      return query.docs.map((d) => RescueCaseModel.fromMap(d.data(), d.id)).toList();
    } catch (e) {
      throw AppFirestoreException('Failed to query citizen cases: $e');
    }
  }

  /// Query active rescue queue for NGOs
  Future<List<RescueCaseModel>> getRescueQueue() async {
    try {
      final query = await _firestore
          .collection(FirebaseConstants.colRescueCases)
          .where('status', isEqualTo: 'pending')
          .limit(50)
          .get();

      return query.docs.map((d) => RescueCaseModel.fromMap(d.data(), d.id)).toList();
    } catch (e) {
      throw AppFirestoreException('Failed to get rescue queue: $e');
    }
  }

  /// Update stage progression status
  Future<void> updateCaseStatus({
    required String caseId,
    required String status,
    String? notes,
    String? photoBase64,
    String? actorId,
    String? actorRole,
  }) async {
    try {
      final batch = _firestore.batch();
      final caseRef = _firestore.collection(FirebaseConstants.colRescueCases).doc(caseId);

      batch.update(caseRef, {
        'status': status,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
        if (notes != null) 'notes': notes,
      });

      final eventRef = caseRef.collection(FirebaseConstants.subcolEvents).doc();
      batch.set(eventRef, {
        'eventType': 'STATUS_CHANGE',
        'newStatus': status,
        'notes': notes,
        'photoBase64': photoBase64,
        'actorId': actorId,
        'actorRole': actorRole,
        'timestamp': FieldValue.serverTimestamp(),
      });

      await batch.commit();
    } catch (e) {
      throw AppFirestoreException('Failed to update case status: $e');
    }
  }

  // ─── NGOs ──────────────────────────────────────────────────────────────────

  Future<NgoModel?> getNgo(String ngoId) async {
    try {
      final doc = await _firestore.collection(FirebaseConstants.colNgos).doc(ngoId).get();
      if (!doc.exists || doc.data() == null) return null;
      return NgoModel.fromMap(doc.data()!, doc.id);
    } catch (e) {
      throw AppFirestoreException('Failed to get NGO: $e');
    }
  }

  Future<List<NgoModel>> getApprovedNgos() async {
    try {
      final query = await _firestore
          .collection(FirebaseConstants.colNgos)
          .where('status', isEqualTo: 'approved')
          .get();
      return query.docs.map((d) => NgoModel.fromMap(d.data(), d.id)).toList();
    } catch (e) {
      throw AppFirestoreException('Failed to get approved NGOs: $e');
    }
  }

  // ─── Notifications ─────────────────────────────────────────────────────────

  Future<List<NotificationModel>> getNotifications(String userId) async {
    try {
      final query = await _firestore
          .collection(FirebaseConstants.colNotifications)
          .where('recipient_user_id', isEqualTo: userId)
          .limit(30)
          .get();

      return query.docs.map((d) => NotificationModel.fromMap(d.data(), d.id)).toList();
    } catch (e) {
      throw AppFirestoreException('Failed to get notifications: $e');
    }
  }
}
