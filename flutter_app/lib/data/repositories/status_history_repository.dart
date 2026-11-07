// lib/data/repositories/status_history_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/firebase/firebase_constants.dart';
import '../models/status_history_model.dart';

abstract class StatusHistoryRepository {
  Stream<List<StatusHistoryModel>> streamStatusHistory(String reportId);
  Future<List<StatusHistoryModel>> getStatusHistory(String reportId);
  Future<void> addStatusEntry(StatusHistoryModel entry);
}

class FirestoreStatusHistoryRepository implements StatusHistoryRepository {
  final FirebaseFirestore _firestore;

  FirestoreStatusHistoryRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _subcollection(String reportId) => _firestore
      .collection(FirebaseConstants.colReports)
      .doc(reportId)
      .collection(FirebaseConstants.subcolStatusHistory);

  @override
  Stream<List<StatusHistoryModel>> streamStatusHistory(String reportId) {
    return _subcollection(reportId)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((d) => StatusHistoryModel.fromMap(d.data(), d.id)).toList());
  }

  @override
  Future<List<StatusHistoryModel>> getStatusHistory(String reportId) async {
    try {
      final snapshot = await _subcollection(reportId)
          .orderBy('timestamp', descending: false)
          .get();

      return snapshot.docs.map((d) => StatusHistoryModel.fromMap(d.data(), d.id)).toList();
    } catch (e) {
      throw AppFirestoreException('Failed to get status history: $e');
    }
  }

  @override
  Future<void> addStatusEntry(StatusHistoryModel entry) async {
    try {
      final map = entry.toMap();
      map['timestamp'] = FieldValue.serverTimestamp();
      await _subcollection(entry.reportId).doc(entry.historyId).set(map);
    } catch (e) {
      throw AppFirestoreException('Failed to record status progression: $e');
    }
  }
}
