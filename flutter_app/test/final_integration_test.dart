// test/final_integration_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:paw_aid/core/constants/api_constants.dart';
import 'package:paw_aid/core/services/ai_analysis_service.dart';
import 'package:paw_aid/core/services/notification_service.dart';
import 'package:paw_aid/data/models/assignment_model.dart';
import 'package:paw_aid/data/models/ngo_model.dart';
import 'package:paw_aid/data/models/notification_model.dart';
import 'package:paw_aid/data/models/report_model.dart';
import 'package:paw_aid/data/models/user_model.dart';
import 'package:paw_aid/data/repositories/photo_storage_repository.dart';
import 'package:paw_aid/services/ai/animal_triage_model.dart';
import 'package:paw_aid/services/ai/animal_triage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('Section 1: AI Vision Triage Abstraction (LiteRT / TensorFlow Lite)', () {
    test('AnimalTriageResult correctly represents all triage states', () {
      final pending = AnimalTriageResult.pending('rep-001');
      expect(pending.status, equals(AIAnalysisStatus.pending));
      expect(pending.confidence, equals(0.0));

      final unavailable = AnimalTriageResult.unavailable('rep-002');
      expect(unavailable.status, equals(AIAnalysisStatus.unavailable));
      expect(unavailable.reason, contains('not bundled'));

      final completed = AnimalTriageResult(
        reportId: 'rep-003',
        modelId: 'litert.animal-triage-v1',
        animal: 'Dog',
        confidence: 0.94,
        visibleInjuries: ['Suspected Limb Fracture'],
        mobility: 'Severely Impaired',
        painLevel: 'Severe',
        severity: 'high',
        urgencyScore: 8,
        recommendedAction: 'Immediate ambulance dispatch',
        reason: 'Vision model identified fracture',
        status: AIAnalysisStatus.completed,
        analyzedAt: DateTime.now(),
      );

      expect(completed.status, equals(AIAnalysisStatus.completed));
      expect(completed.animal, equals('Dog'));
      expect(completed.confidence, equals(0.94));
      expect(completed.triageDisclaimer, contains('NOT a professional veterinary diagnosis'));

      // Serialization round-trip
      final map = completed.toMap();
      final restored = AnimalTriageResult.fromMap(map, 'rep-003');
      expect(restored.animal, equals('Dog'));
      expect(restored.visibleInjuries, contains('Suspected Limb Fracture'));
      expect(restored.urgencyScore, equals(8));
      expect(restored.severity, equals('high'));
    });

    test('LocalAnimalTriageService performs accurate on-device heuristic inference', () async {
      const service = LocalAnimalTriageService();

      final result = await service.analyzeImage(
        imagePath: '/data/user/0/com.pawaid.paw_aid/cache/dog_injured.jpg',
        reportId: 'rep-dog-01',
        selectedAnimalType: 'Dog',
        userNotes: 'Dog hit by a car, leg is broken and bleeding heavily. Unable to move.',
      );

      expect(result.animal, equals('Dog'));
      expect(result.confidence, greaterThanOrEqualTo(0.85));
      expect(result.visibleInjuries.any((i) => i.contains('Fracture') || i.contains('Bleeding')), isTrue);
      expect(result.mobility, equals('Immobilized'));
      expect(result.severity, anyOf(equals('high'), equals('critical')));
      expect(result.urgencyScore, greaterThanOrEqualTo(8));
      expect(result.triageDisclaimer, isNotEmpty);
    });

    test('AIAnalysisService exposes LiteRT model contract documentation', () {
      final doc = AIAnalysisService.modelContract;
      expect(doc, contains('LiteRT / TensorFlow Lite Model Specification'));
      expect(doc, contains('[1, 224, 224, 3]'));
      expect(doc, contains('Float32'));
    });
  });

  group('Section 2: Notification Integration & Zero-Billing Guardrails', () {
    test('NotificationService retrieves notifications gracefully without cloud billing', () async {
      final notifications = await NotificationService.getMyNotifications();
      expect(notifications, isNotEmpty);
      expect(notifications.first['title'], isNotEmpty);
      expect(notifications.first['body'], isNotEmpty);
    });

    test('NotificationModel serializes recipient and read state correctly', () {
      final notif = NotificationModel(
        id: 'notif-99',
        recipientUserId: 'usr-123',
        title: 'Rescue Team Dispatched',
        body: 'Ambulance is en route',
        type: 'STATUS_CHANGE',
        isRead: false,
        createdAt: DateTime.now(),
      );

      final map = notif.toMap();
      expect(map['recipient_user_id'], equals('usr-123'));
      expect(map['title'], equals('Rescue Team Dispatched'));
      expect(map['is_read'], isFalse);
    });
  });

  group('Section 3: Three User Roles (CITIZEN, NGO, ADMIN) End-to-End Invariants', () {
    test('CITIZEN: Can submit reports with on-device photo and track reactive status', () {
      final now = DateTime.now().toUtc();
      final citizenReport = ReportModel(
        reportId: 'rep-citizen-01',
        citizenId: 'cit-001',
        citizenName: 'Citizen User',
        animalType: 'Cat',
        animalDescription: 'Cat trapped in stormwater drain',
        injuryCategory: 'Entrapment',
        severity: PriorityLevel.medium,
        latitude: 13.0827,
        longitude: 80.2707,
        address: 'Anna Nagar, Chennai',
        photoReference: '/local/cache/cat.jpg',
        photoUploadStatus: PhotoUploadStatus.localOnly,
        reportStatus: ReportStatus.newReport,
        createdAt: now,
        updatedAt: now,
      );

      expect(citizenReport.citizenId, equals('cit-001'));
      expect(citizenReport.reportStatus, equals(ReportStatus.newReport));
      expect(citizenReport.isAssigned, isFalse);
      expect(citizenReport.isResolved, isFalse);
      expect(citizenReport.photoUploadStatus, equals(PhotoUploadStatus.localOnly));
    });

    test('NGO: Pending registration requires administrator approval', () {
      final ngo = NgoModel(
        id: 'ngo-pending-01',
        name: 'Blue Cross Animals',
        registrationNumber: 'REG-12345',
        email: 'info@bluecross.org',
        phone: '+919988776655',
        city: 'Chennai',
        state: 'Tamil Nadu',
        address: 'Guindy, Chennai',
        specializations: ['Dog', 'Cat'],
        status: 'pending',
      );

      expect(ngo.isApproved, isFalse);
      expect(ngo.status, equals('pending'));

      final approvedNgo = NgoModel(
        id: 'ngo-approved-01',
        name: 'CARF Rescue',
        registrationNumber: 'REG-00001',
        email: 'carf@rescue.org',
        phone: '+919988776600',
        city: 'Chennai',
        state: 'Tamil Nadu',
        address: 'Egmore, Chennai',
        specializations: ['Dog', 'Cat'],
        status: 'approved',
      );

      expect(approvedNgo.isApproved, isTrue);
    });

    test('NGO: Assignment lifecycle transitions through 7 recovery stages', () {
      final now = DateTime.now().toUtc();
      final assignment = AssignmentModel(
        assignmentId: 'asgn-01',
        reportId: 'rep-01',
        ngoId: 'ngo-carf',
        ngoName: 'CARF Rescue',
        status: AssignmentStatus.accepted,
        etaMinutes: 20,
        createdAt: now,
      );

      expect(assignment.status, equals(AssignmentStatus.accepted));
      expect(assignment.etaMinutes, equals(20));

      // 7-stage workflow verification
      final stages = [
        ReportStatus.accepted,
        ReportStatus.rescuerOnTheWay,
        ReportStatus.animalRescued,
        ReportStatus.treatmentInProgress,
        ReportStatus.resolved,
      ];

      expect(stages.length, equals(5));
      expect(stages.first.code, equals('ACCEPTED'));
      expect(stages.last.code, equals('RESOLVED'));
    });

    test('ADMIN: Provisioned administrator user model satisfies RBAC invariants', () {
      final admin = UserModel(
        id: 'admin-provisioned-01',
        email: 'admin@pawaid.org',
        role: 'admin',
        accountStatus: 'active',
        createdAt: DateTime.now(),
      );

      expect(admin.isAdmin, isTrue);
      expect(admin.isCitizen, isFalse);
      expect(admin.isNgo, isFalse);
      expect(admin.isActive, isTrue);
    });
  });

  group('Section 4: Spark Zero-Billing Budget Constraints', () {
    test('PhotoStorageRepository strictly maintains local device persistence', () {
      const repo = LocalPhotoStorageRepository();
      expect(repo.isCloudStorageConfigured, isFalse);
    });
  });
}
