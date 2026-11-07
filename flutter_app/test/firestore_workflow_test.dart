// test/firestore_workflow_test.dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:paw_aid/core/constants/api_constants.dart';
import 'package:paw_aid/data/models/assignment_model.dart';
import 'package:paw_aid/data/models/report_model.dart';
import 'package:paw_aid/data/models/status_history_model.dart';
import 'package:paw_aid/data/repositories/photo_storage_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReportStatus Lifecycle & Normalization', () {
    test('Standard Part 5 statuses deserialize accurately', () {
      expect(ReportStatus.fromString('NEW'), equals(ReportStatus.newReport));
      expect(ReportStatus.fromString('UNDER_REVIEW'), equals(ReportStatus.underReview));
      expect(ReportStatus.fromString('ASSIGNED'), equals(ReportStatus.assigned));
      expect(ReportStatus.fromString('ACCEPTED'), equals(ReportStatus.accepted));
      expect(ReportStatus.fromString('RESCUER_ON_THE_WAY'), equals(ReportStatus.rescuerOnTheWay));
      expect(ReportStatus.fromString('ANIMAL_RESCUED'), equals(ReportStatus.animalRescued));
      expect(ReportStatus.fromString('TREATMENT_IN_PROGRESS'), equals(ReportStatus.treatmentInProgress));
      expect(ReportStatus.fromString('RESOLVED'), equals(ReportStatus.resolved));
      expect(ReportStatus.fromString('REJECTED'), equals(ReportStatus.rejected));
    });

    test('Legacy application terminology correctly maps to Part 5 statuses', () {
      expect(ReportStatus.fromString('reported'), equals(ReportStatus.newReport));
      expect(ReportStatus.fromString('open'), equals(ReportStatus.newReport));
      expect(ReportStatus.fromString('pending'), equals(ReportStatus.underReview));
      expect(ReportStatus.fromString('awaiting_ngo'), equals(ReportStatus.underReview));
      expect(ReportStatus.fromString('dispatched'), equals(ReportStatus.rescuerOnTheWay));
      expect(ReportStatus.fromString('rescued'), equals(ReportStatus.animalRescued));
      expect(ReportStatus.fromString('treatment'), equals(ReportStatus.treatmentInProgress));
      expect(ReportStatus.fromString('closed'), equals(ReportStatus.resolved));
      expect(ReportStatus.fromString('rejected'), equals(ReportStatus.rejected));
      expect(ReportStatus.fromString(null), equals(ReportStatus.newReport));
    });

    test('ReportStatus maps to legacy CaseStatus for UI backwards compatibility', () {
      expect(ReportStatus.newReport.toCaseStatus(), equals(CaseStatus.pending));
      expect(ReportStatus.underReview.toCaseStatus(), equals(CaseStatus.pending));
      expect(ReportStatus.assigned.toCaseStatus(), equals(CaseStatus.accepted));
      expect(ReportStatus.accepted.toCaseStatus(), equals(CaseStatus.accepted));
      expect(ReportStatus.rescuerOnTheWay.toCaseStatus(), equals(CaseStatus.dispatched));
      expect(ReportStatus.animalRescued.toCaseStatus(), equals(CaseStatus.animalPicked));
      expect(ReportStatus.treatmentInProgress.toCaseStatus(), equals(CaseStatus.vetTreatment));
      expect(ReportStatus.resolved.toCaseStatus(), equals(CaseStatus.completed));
      expect(ReportStatus.rejected.toCaseStatus(), equals(CaseStatus.closed));
    });
  });

  group('ReportModel Serialization & Invariants', () {
    test('ReportModel serializes and deserializes dual schema fields seamlessly', () {
      final now = DateTime.now().toUtc();
      final report = ReportModel(
        reportId: 'rep-test-001',
        citizenId: 'cit-user-123',
        citizenName: 'Aditi Sharma',
        citizenPhone: '+919876543210',
        animalType: 'Street Dog',
        animalDescription: 'Fractured hind leg near park entrance',
        injuryCategory: 'Severe Trauma',
        severity: PriorityLevel.high,
        latitude: 12.9716,
        longitude: 77.5946,
        address: 'MG Road, Bangalore',
        photoReference: '/data/user/0/com.pawaid.paw_aid/app_flutter/reports/rep-test-001.jpg',
        photoUploadStatus: PhotoUploadStatus.localOnly,
        assignedNgoId: 'ngo-999',
        assignedNgoName: 'Bangalore Animal Care',
        reportStatus: ReportStatus.assigned,
        createdAt: now,
        updatedAt: now,
      );

      final map = report.toMap();

      // Verify Firestore dual fields
      expect(map['reportId'], equals('rep-test-001'));
      expect(map['case_id'], equals('rep-test-001'));
      expect(map['citizenId'], equals('cit-user-123'));
      expect(map['reporterId'], equals('cit-user-123'));
      expect(map['reportStatus'], equals('ASSIGNED'));
      expect(map['status'], equals('accepted'));
      expect(map['photoUploadStatus'], equals('localOnly'));
      expect(map['photoReference'], contains('rep-test-001.jpg'));

      // Deserialization round-trip
      final restored = ReportModel.fromMap(map, 'rep-test-001');
      expect(restored.reportId, equals('rep-test-001'));
      expect(restored.citizenId, equals('cit-user-123'));
      expect(restored.animalType, equals('Street Dog'));
      expect(restored.severity, equals(PriorityLevel.high));
      expect(restored.reportStatus, equals(ReportStatus.assigned));
      expect(restored.photoUploadStatus, equals(PhotoUploadStatus.localOnly));
      expect(restored.isAssigned, isTrue);
      expect(restored.isResolved, isFalse);
    });
  });

  group('PhotoStorageRepository - Spark Free Tier Compliance', () {
    test('LocalPhotoStorageRepository does NOT store Base64 in cloud and saves locally', () async {
      const repo = LocalPhotoStorageRepository();

      // Create a test dummy file
      final tempDir = Directory.systemTemp;
      final testFile = File('${tempDir.path}/test_image.jpg');
      await testFile.writeAsString('mock binary photo bytes');

      final ref = await repo.saveLocalPhoto(
        reportId: 'test-rep-spark',
        sourcePath: testFile.path,
      );

      expect(ref, equals(testFile.path));
      expect(repo.isCloudStorageConfigured, isFalse);

      final path = await repo.getPhotoLocalPath(ref);
      expect(path, equals(testFile.path));

      final status = await repo.getUploadStatus(ref);
      expect(status, equals(PhotoUploadStatus.pendingStorageProvider));

      // Cleanup
      final deleted = await repo.deletePhoto(ref);
      expect(deleted, isTrue);
    });

    test('PhotoUploadStatus describes Spark cloud state honestly', () {
      expect(PhotoUploadStatus.localOnly.name, equals('localOnly'));
      expect(PhotoUploadStatus.pendingStorageProvider.name, equals('pendingStorageProvider'));
      expect(PhotoUploadStatus.fromString('localOnly'), equals(PhotoUploadStatus.localOnly));
      expect(PhotoUploadStatus.fromString('pendingStorageProvider'), equals(PhotoUploadStatus.pendingStorageProvider));
      expect(PhotoUploadStatus.pendingStorageProvider.displayName, contains('Spark Mode'));
    });
  });

  group('AssignmentModel & StatusHistoryModel', () {
    test('AssignmentModel serializes and deserializes accurately', () {
      final now = DateTime.now().toUtc();
      final assignment = AssignmentModel(
        assignmentId: 'asgn-001',
        reportId: 'rep-001',
        ngoId: 'ngo-carf',
        ngoName: 'CARF Rescue',
        status: AssignmentStatus.assigned,
        assignedBy: 'admin-01',
        etaMinutes: 25,
        notes: 'Ambulance dispatched',
        createdAt: now,
      );

      final map = assignment.toMap();
      expect(map['assignmentId'], equals('asgn-001'));
      expect(map['reportId'], equals('rep-001'));
      expect(map['ngoId'], equals('ngo-carf'));
      expect(map['status'], equals('ASSIGNED'));
      expect(map['etaMinutes'], equals(25));

      final restored = AssignmentModel.fromMap(map, 'asgn-001');
      expect(restored.assignmentId, equals('asgn-001'));
      expect(restored.status, equals(AssignmentStatus.assigned));
      expect(restored.etaMinutes, equals(25));
    });

    test('StatusHistoryModel models append-only progression entries', () {
      final now = DateTime.now().toUtc();
      final history = StatusHistoryModel(
        historyId: 'hist-001',
        reportId: 'rep-001',
        previousStatus: 'ASSIGNED',
        newStatus: 'RESCUER_ON_THE_WAY',
        actorId: 'ngo-carf',
        actorRole: 'ngo_staff',
        notes: 'Rescuer en route with crate',
        timestamp: now,
      );

      final map = history.toMap();
      expect(map['historyId'], equals('hist-001'));
      expect(map['newStatus'], equals('RESCUER_ON_THE_WAY'));
      expect(map['previousStatus'], equals('ASSIGNED'));
      expect(map['actorRole'], equals('ngo_staff'));

      final restored = StatusHistoryModel.fromMap(map, 'hist-001');
      expect(restored.historyId, equals('hist-001'));
      expect(restored.newStatus, equals('RESCUER_ON_THE_WAY'));
      expect(restored.actorRole, equals('ngo_staff'));
    });
  });
}
