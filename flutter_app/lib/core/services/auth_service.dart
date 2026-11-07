// lib/core/services/auth_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../errors/app_exceptions.dart';
import '../../services/auth/firebase_auth_service.dart';

class AuthUser {
  final String id;
  final String email;
  final String role;
  final String? displayName;
  final String? phone;
  final String accountStatus;

  const AuthUser({
    required this.id,
    required this.email,
    required this.role,
    this.displayName,
    this.phone,
    this.accountStatus = 'active',
  });

  bool get isCitizen => role == 'citizen' || role == 'CITIZEN';
  bool get isNgo => role == 'ngo_staff' || role == 'ngo' || role == 'NGO';
  bool get isAdmin => role == 'admin' || role == 'ADMIN';
  bool get isPending => accountStatus.toLowerCase() == 'pending';
  bool get isActive => accountStatus.toLowerCase() == 'active';

  Map<String, dynamic> toMap() => {
        'id': id,
        'uid': id,
        'email': email,
        'role': role,
        'display_name': displayName,
        'fullName': displayName,
        'phone': phone,
        'phoneNumber': phone,
        'accountStatus': accountStatus,
        'account_status': accountStatus,
      };

  factory AuthUser.fromMap(Map<String, dynamic> map) => AuthUser(
        id: (map['uid'] ?? map['id'] ?? '') as String,
        email: (map['email'] ?? '') as String,
        role: (map['role'] ?? 'citizen') as String,
        displayName: (map['display_name'] ?? map['fullName']) as String?,
        phone: (map['phone'] ?? map['phoneNumber']) as String?,
        accountStatus: (map['accountStatus'] ?? map['account_status'] ?? 'active') as String,
      );
}

/// Authentication Service
/// Bridges FlutterFire Authentication, role-based access control (RBAC),
/// persistent login sessions, and offline demo role switching.
class AuthService {
  AuthService._();

  static const _storage = FlutterSecureStorage();
  static const _keyAuthToken = 'app_auth_token';
  static const _keyCurrentUser = 'app_current_user_profile';
  static final FirebaseAuthService _firebaseAuthService = FirebaseAuthService();

  /// Sign In with Email & Password
  static Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();

    // 1. Check if user is using 1-tap exhibition demo credentials
    if (_isDemoAccount(cleanEmail)) {
      return _signInDemoAccount(cleanEmail);
    }

    // 2. Authenticate against Firebase Authentication
    try {
      final userModel = await _firebaseAuthService.signInWithEmailPassword(
        email: cleanEmail,
        password: password,
      );

      final authUser = AuthUser(
        id: userModel.id,
        email: userModel.email,
        role: userModel.role,
        displayName: userModel.displayName,
        phone: userModel.phone,
        accountStatus: userModel.accountStatus,
      );

      // Verify NGO approval status
      if (authUser.isNgo && authUser.isPending) {
        throw const AccountPendingApprovalException();
      }

      // Save persistent user session
      await _storage.write(key: _keyCurrentUser, value: jsonEncode(authUser.toMap()));
      await _storage.write(key: _keyAuthToken, value: 'firebase-${authUser.id}');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('bypass_role', authUser.role);

      return authUser;
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppAuthException(e.toString());
    }
  }

  /// Sign In with predefined Exhibition Demo Roles (CITIZEN, NGO, ADMIN)
  static Future<AuthUser> signInWithRole(String role, {String? overrideEmail}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('bypass_role', role);

    String id;
    String email;
    String name;
    String phone;
    String accountStatus = 'active';

    if (role == 'admin') {
      id = 'admin-demo-00000001';
      email = overrideEmail ?? 'admin@pawaid.com';
      name = 'PAW-AID Administrator';
      phone = '+919000000001';
    } else if (role == 'ngo_staff' || role == 'ngo') {
      id = 'ngo-demo-00000002';
      email = overrideEmail ?? 'ngo@pawaid.com';
      name = 'Chennai Rescue Dispatcher';
      phone = '+914411223344';
      role = 'ngo_staff';
    } else {
      id = 'citizen-demo-00000003';
      email = overrideEmail ?? 'citizen@pawaid.com';
      name = 'Priya Ramesh (Animal Lover)';
      phone = '+919876543210';
      role = 'citizen';
    }

    final user = AuthUser(
      id: id,
      email: email,
      role: role,
      displayName: name,
      phone: phone,
      accountStatus: accountStatus,
    );

    await _storage.write(key: _keyCurrentUser, value: jsonEncode(user.toMap()));
    await _storage.write(key: _keyAuthToken, value: 'auth-token-$role-$id');

    return user;
  }

  /// Register a new account
  /// Strict RBAC Rule: Public registration assigns CITIZEN role automatically.
  /// Admin accounts can NEVER be created through public registration.
  static Future<AuthUser> signUp({
    required String email,
    required String password,
    required String displayName,
    String? phone,
    String role = 'citizen',
  }) async {
    final cleanEmail = email.trim().toLowerCase();

    // Prevent public registration from assigning admin role
    if (role.toLowerCase() == 'admin') {
      throw const UnauthorizedRoleException(
        'Public registration for Administrator accounts is not permitted.',
      );
    }

    try {
      final userModel = await _firebaseAuthService.signUpWithEmailPassword(
        email: cleanEmail,
        password: password,
        displayName: displayName,
        phone: phone,
        role: role,
      );

      final authUser = AuthUser(
        id: userModel.id,
        email: userModel.email,
        role: userModel.role,
        displayName: userModel.displayName,
        phone: userModel.phone,
        accountStatus: userModel.accountStatus,
      );

      await _storage.write(key: _keyCurrentUser, value: jsonEncode(authUser.toMap()));
      await _storage.write(key: _keyAuthToken, value: 'firebase-${authUser.id}');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('bypass_role', authUser.role);

      return authUser;
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppAuthException(e.toString());
    }
  }

  /// Send Password Reset Email
  static Future<void> sendPasswordResetEmail(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty) {
      throw const AppAuthException('Please enter your registered email address.');
    }
    await _firebaseAuthService.sendPasswordResetEmail(cleanEmail);
  }

  /// Sign out
  static Future<void> signOut() async {
    try {
      await _firebaseAuthService.signOut();
    } catch (e) {
      debugPrint('[AuthService] Firebase signout error: $e');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('bypass_role');
    await _storage.deleteAll();
  }

  /// Get current user profile (from memory/storage or active Firebase session)
  static Future<AuthUser?> getCurrentUser() async {
    // 1. Check if Firebase currentUser exists
    final currentFbUser = _firebaseAuthService.currentFirebaseUser;
    if (currentFbUser != null) {
      final profile = await _firebaseAuthService.getUserProfile(currentFbUser.uid);
      if (profile != null) {
        return AuthUser(
          id: profile.id,
          email: profile.email,
          role: profile.role,
          displayName: profile.displayName,
          phone: profile.phone,
          accountStatus: profile.accountStatus,
        );
      }
    }

    // 2. Check cached secure storage
    final raw = await _storage.read(key: _keyCurrentUser);
    if (raw != null) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        return AuthUser.fromMap(map);
      } catch (_) {}
    }

    return null;
  }

  /// Get active authentication token
  static Future<String?> getToken() async {
    return _storage.read(key: _keyAuthToken);
  }

  /// Update FCM device token
  static Future<void> updateFcmToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fcm_token', token);
  }

  static bool _isDemoAccount(String email) {
    return email == 'citizen@pawaid.com' ||
        email == 'ngo@pawaid.com' ||
        email == 'admin@pawaid.com';
  }

  static Future<AuthUser> _signInDemoAccount(String email) async {
    if (email == 'admin@pawaid.com') {
      return signInWithRole('admin', overrideEmail: email);
    } else if (email == 'ngo@pawaid.com') {
      return signInWithRole('ngo_staff', overrideEmail: email);
    } else {
      return signInWithRole('citizen', overrideEmail: email);
    }
  }
}
