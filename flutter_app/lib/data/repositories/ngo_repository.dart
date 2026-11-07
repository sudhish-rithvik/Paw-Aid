// lib/data/repositories/ngo_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/firebase/firebase_constants.dart';
import '../models/ngo_model.dart';

abstract class NgoRepository {
  Future<NgoModel?> getNgo(String ngoId);
  Stream<NgoModel?> streamNgo(String ngoId);
  Future<List<NgoModel>> getApprovedNgos();
  Future<List<NgoModel>> getPendingNgos();
  Future<void> registerNgo(NgoModel ngo);
  Future<void> verifyNgo(String ngoId, bool approved, {String? rejectionReason});
  Future<void> updateNgoProfile(NgoModel ngo);
}

class FirestoreNgoRepository implements NgoRepository {
  final FirebaseFirestore _firestore;

  FirestoreNgoRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _ngosRef =>
      _firestore.collection(FirebaseConstants.colNgos);

  @override
  Future<NgoModel?> getNgo(String ngoId) async {
    try {
      final doc = await _ngosRef.doc(ngoId).get();
      if (!doc.exists || doc.data() == null) return null;
      return NgoModel.fromMap(doc.data()!, doc.id);
    } catch (e) {
      throw AppFirestoreException('Failed to get NGO details: $e');
    }
  }

  @override
  Stream<NgoModel?> streamNgo(String ngoId) {
    return _ngosRef.doc(ngoId).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) return null;
      return NgoModel.fromMap(snapshot.data()!, snapshot.id);
    });
  }

  @override
  Future<List<NgoModel>> getApprovedNgos() async {
    try {
      final snapshot = await _ngosRef.where('status', isEqualTo: 'approved').get();
      return snapshot.docs.map((d) => NgoModel.fromMap(d.data(), d.id)).toList();
    } catch (e) {
      throw AppFirestoreException('Failed to query approved NGOs: $e');
    }
  }

  @override
  Future<List<NgoModel>> getPendingNgos() async {
    try {
      final snapshot = await _ngosRef.where('status', isEqualTo: 'pending').get();
      return snapshot.docs.map((d) => NgoModel.fromMap(d.data(), d.id)).toList();
    } catch (e) {
      throw AppFirestoreException('Failed to query pending NGOs: $e');
    }
  }

  @override
  Future<void> registerNgo(NgoModel ngo) async {
    try {
      final map = ngo.toMap();
      map['status'] = 'pending';
      map['verification_status'] = 'pending';
      map['createdAt'] = FieldValue.serverTimestamp();
      map['updatedAt'] = FieldValue.serverTimestamp();

      await _ngosRef.doc(ngo.id).set(map);
    } catch (e) {
      throw AppFirestoreException('Failed to submit NGO registration: $e');
    }
  }

  @override
  Future<void> verifyNgo(String ngoId, bool approved, {String? rejectionReason}) async {
    try {
      final batch = _firestore.batch();
      final ngoDoc = _ngosRef.doc(ngoId);
      final newStatus = approved ? 'approved' : 'rejected';

      batch.update(ngoDoc, {
        'status': newStatus,
        'verification_status': approved ? 'verified' : 'rejected',
        if (rejectionReason != null) 'rejection_reason': rejectionReason,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Also update matching user account status if linked
      final userDoc = _firestore.collection(FirebaseConstants.colUsers).doc(ngoId);
      final userSnap = await userDoc.get();
      if (userSnap.exists) {
        batch.update(userDoc, {
          'accountStatus': approved ? 'active' : 'rejected',
          'account_status': approved ? 'active' : 'rejected',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    } catch (e) {
      throw AppFirestoreException('Failed to verify NGO credentials: $e');
    }
  }

  @override
  Future<void> updateNgoProfile(NgoModel ngo) async {
    try {
      final map = ngo.toMap();
      map['updatedAt'] = FieldValue.serverTimestamp();
      // Immutable fields protected from self-approval
      map.remove('status');
      map.remove('verification_status');

      await _ngosRef.doc(ngo.id).update(map);
    } catch (e) {
      throw AppFirestoreException('Failed to update NGO organization profile: $e');
    }
  }
}
