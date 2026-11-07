// test/auth_test.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:paw_aid/core/errors/app_exceptions.dart';
import 'package:paw_aid/core/firebase/firebase_constants.dart';
import 'package:paw_aid/core/services/auth_service.dart';
import 'package:paw_aid/data/models/user_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('UserModel & RBAC Invariants', () {
    test('Citizen role is correctly identified and defaults to active', () {
      final user = UserModel(
        id: 'user-citizen-1',
        email: 'citizen@example.com',
        role: FirebaseConstants.roleCitizen,
        createdAt: DateTime.now(),
      );

      expect(user.isCitizen, isTrue);
      expect(user.isNgo, isFalse);
      expect(user.isAdmin, isFalse);
      expect(user.isActive, isTrue);
      expect(user.isPending, isFalse);
    });

    test('NGO role is identified and reflects pending approval status', () {
      final user = UserModel(
        id: 'user-ngo-1',
        email: 'ngo@example.com',
        role: FirebaseConstants.roleNgo,
        accountStatus: 'pending',
        createdAt: DateTime.now(),
      );

      expect(user.isNgo, isTrue);
      expect(user.isCitizen, isFalse);
      expect(user.isAdmin, isFalse);
      expect(user.isPending, isTrue);
      expect(user.isActive, isFalse);
    });

    test('Admin role is identified', () {
      final user = UserModel(
        id: 'user-admin-1',
        email: 'admin@example.com',
        role: FirebaseConstants.roleAdmin,
        accountStatus: 'active',
        createdAt: DateTime.now(),
      );

      expect(user.isAdmin, isTrue);
      expect(user.isCitizen, isFalse);
      expect(user.isNgo, isFalse);
      expect(user.isActive, isTrue);
    });

    test('Serialization toMap preserves uid, fullName, and accountStatus', () {
      final user = UserModel(
        id: 'uid-test-123',
        email: 'test@domain.com',
        role: 'citizen',
        displayName: 'Test Citizen',
        phone: '+919876543210',
        accountStatus: 'active',
        createdAt: DateTime(2026, 1, 1),
      );

      final map = user.toMap();
      expect(map['uid'], equals('uid-test-123'));
      expect(map['email'], equals('test@domain.com'));
      expect(map['role'], equals('citizen'));
      expect(map['fullName'], equals('Test Citizen'));
      expect(map['phoneNumber'], equals('+919876543210'));
      expect(map['accountStatus'], equals('active'));

      final reconstructed = UserModel.fromMap(map, 'uid-test-123');
      expect(reconstructed.uid, equals('uid-test-123'));
      expect(reconstructed.fullName, equals('Test Citizen'));
      expect(reconstructed.role, equals('citizen'));
      expect(reconstructed.accountStatus, equals('active'));
    });
  });

  group('Public Registration RBAC Security Restrictions', () {
    test('AuthService.signUp prevents admin registration', () async {
      expect(
        () => AuthService.signUp(
          email: 'wannabe_admin@test.com',
          password: 'password123',
          displayName: 'Wannabe Admin',
          role: 'admin',
        ),
        throwsA(isA<UnauthorizedRoleException>()),
      );
    });

    test('AuthService.signUp prevents ADMIN uppercase registration', () async {
      expect(
        () => AuthService.signUp(
          email: 'wannabe_admin@test.com',
          password: 'password123',
          displayName: 'Wannabe Admin',
          role: 'ADMIN',
        ),
        throwsA(isA<UnauthorizedRoleException>()),
      );
    });
  });

  group('AuthUser & Demo Session Invariants', () {
    test('Demo admin session has admin role and is active', () async {
      final adminUser = await AuthService.signInWithRole('admin');
      expect(adminUser.isAdmin, isTrue);
      expect(adminUser.isActive, isTrue);
      expect(adminUser.email, equals('admin@pawaid.com'));
    });

    test('Demo NGO session has ngo role and is active', () async {
      final ngoUser = await AuthService.signInWithRole('ngo_staff');
      expect(ngoUser.isNgo, isTrue);
      expect(ngoUser.email, equals('ngo@pawaid.com'));
    });

    test('Demo Citizen session has citizen role', () async {
      final citizenUser = await AuthService.signInWithRole('citizen');
      expect(citizenUser.isCitizen, isTrue);
      expect(citizenUser.email, equals('citizen@pawaid.com'));
    });

    test('Password reset with empty email throws AppAuthException', () async {
      expect(
        () => AuthService.sendPasswordResetEmail(''),
        throwsA(isA<AppAuthException>()),
      );
    });
  });
}
