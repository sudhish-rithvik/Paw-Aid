// lib/data/repositories/auth_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/firebase/firebase_constants.dart';
import '../../services/auth/firebase_auth_service.dart';
import '../models/user_model.dart';

abstract class AuthRepository {
  Future<UserModel?> getCurrentUser();
  Stream<UserModel?> authStateChanges();
  Future<UserModel> signInWithEmailPassword(String email, String password);
  Future<UserModel> signUpWithEmailPassword(
    String email,
    String password,
    String displayName, {
    String? phone,
    String role,
  });
  Future<UserModel> signInAnonymously();
  Future<void> sendPasswordResetEmail(String email);
  Future<void> signOut();
  Future<void> updateFcmToken(String token);
}

class AuthRepositoryImpl implements AuthRepository {
  final FirebaseAuthService _authService;

  AuthRepositoryImpl({FirebaseAuthService? authService})
      : _authService = authService ?? FirebaseAuthService();

  @override
  Future<UserModel?> getCurrentUser() async {
    final user = _authService.currentFirebaseUser;
    if (user == null) return null;
    return await _authService.getUserProfile(user.uid);
  }

  @override
  Stream<UserModel?> authStateChanges() {
    return _authService.userModelChanges;
  }

  @override
  Future<UserModel> signInWithEmailPassword(String email, String password) {
    return _authService.signInWithEmailPassword(
      email: email,
      password: password,
    );
  }

  @override
  Future<UserModel> signUpWithEmailPassword(
    String email,
    String password,
    String displayName, {
    String? phone,
    String role = FirebaseConstants.roleCitizen,
  }) {
    return _authService.signUpWithEmailPassword(
      email: email,
      password: password,
      displayName: displayName,
      phone: phone,
      role: role,
    );
  }

  @override
  Future<UserModel> signInAnonymously() {
    return _authService.signInAnonymously();
  }

  @override
  Future<void> sendPasswordResetEmail(String email) {
    return _authService.sendPasswordResetEmail(email);
  }

  @override
  Future<void> signOut() {
    return _authService.signOut();
  }

  @override
  Future<void> updateFcmToken(String token) async {
    final user = _authService.currentFirebaseUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection(FirebaseConstants.colUsers)
          .doc(user.uid)
          .set({'fcm_token': token, 'fcmToken': token}, SetOptions(merge: true));
    }
  }
}
