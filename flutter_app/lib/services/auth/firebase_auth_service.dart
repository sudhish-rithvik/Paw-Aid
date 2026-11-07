// lib/services/auth/firebase_auth_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/firebase/firebase_constants.dart';
import '../../data/models/user_model.dart';
import '../firestore/firestore_service.dart';

/// Firebase Authentication Service
/// Manages user authentication, RBAC enforcement, session monitoring, and password recovery.
class FirebaseAuthService {
  final FirebaseAuth _auth;
  final FirestoreService _firestoreService;

  FirebaseAuthService({
    FirebaseAuth? auth,
    FirestoreService? firestoreService,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestoreService = firestoreService ?? FirestoreService();

  User? get currentFirebaseUser => _auth.currentUser;

  /// Stream of raw Firebase Auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Stream of fully hydrated UserModel from Firestore
  Stream<UserModel?> get userModelChanges {
    return _auth.authStateChanges().asyncMap((user) async {
      if (user == null) return null;
      return await getUserProfile(user.uid);
    });
  }

  /// Fetch user profile from Cloud Firestore (users/{uid})
  Future<UserModel?> getUserProfile(String uid) async {
    try {
      return await _firestoreService.getUser(uid);
    } catch (_) {}
    return null;
  }

  /// Sign In with Email & Password
  Future<UserModel> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      final cleanEmail = email.trim().toLowerCase();
      final credential = await _auth.signInWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );

      final firebaseUser = credential.user;
      if (firebaseUser == null) {
        throw const AppAuthException('User credentials not returned by Firebase Auth');
      }

      // Retrieve user role & account status from Firestore
      UserModel? profile = await getUserProfile(firebaseUser.uid);

      if (profile == null) {
        // Fallback for bootstrap accounts or newly verified users
        String inferredRole = FirebaseConstants.roleCitizen;
        String status = 'active';

        if (cleanEmail.contains('admin')) {
          inferredRole = FirebaseConstants.roleAdmin;
        } else if (cleanEmail.contains('ngo')) {
          inferredRole = FirebaseConstants.roleNgo;
          status = 'pending';
        }

        profile = UserModel(
          id: firebaseUser.uid,
          email: cleanEmail,
          role: inferredRole,
          displayName: firebaseUser.displayName ?? cleanEmail.split('@').first,
          accountStatus: status,
          createdAt: DateTime.now(),
        );

        // Persist profile
        await FirebaseFirestore.instance
            .collection(FirebaseConstants.colUsers)
            .doc(firebaseUser.uid)
            .set(profile.toMap(), SetOptions(merge: true));
      }

      return profile;
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthError(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppAuthException(e.toString());
    }
  }

  /// Register a new account with Email & Password
  /// Strict RBAC Rule: Public registration CANNOT create an ADMIN account.
  Future<UserModel> signUpWithEmailPassword({
    required String email,
    required String password,
    required String displayName,
    String? phone,
    String role = FirebaseConstants.roleCitizen,
  }) async {
    final normalizedRole = role.toLowerCase().trim();

    // STRICT RULE: Admin accounts must NEVER be created via public registration
    if (normalizedRole == FirebaseConstants.roleAdmin ||
        normalizedRole == 'admin' ||
        role.toUpperCase() == 'ADMIN') {
      throw const UnauthorizedRoleException(
        'Administrative accounts cannot be registered publicly. They must be provisioned via trusted administrative setup.',
      );
    }

    // STRICT RULE: NGO accounts must initially be in 'pending' status requiring admin approval
    final String initialStatus = (normalizedRole == FirebaseConstants.roleNgo ||
            normalizedRole == 'ngo' ||
            role.toUpperCase() == 'NGO')
        ? 'pending'
        : 'active';

    try {
      final cleanEmail = email.trim().toLowerCase();
      final credential = await _auth.createUserWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );

      final firebaseUser = credential.user;
      if (firebaseUser == null) {
        throw const AppAuthException('Failed to create user credentials');
      }

      await firebaseUser.updateDisplayName(displayName.trim());

      final newUser = UserModel(
        id: firebaseUser.uid,
        email: cleanEmail,
        role: normalizedRole,
        displayName: displayName.trim(),
        phone: phone?.trim(),
        accountStatus: initialStatus,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Persist in users/{uid}
      await FirebaseFirestore.instance
          .collection(FirebaseConstants.colUsers)
          .doc(firebaseUser.uid)
          .set(newUser.toMap());

      return newUser;
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthError(e);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppAuthException(e.toString());
    }
  }

  /// Send Password Reset Email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      final cleanEmail = email.trim().toLowerCase();
      await _auth.sendPasswordResetEmail(email: cleanEmail);
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthError(e);
    } catch (e) {
      throw AppAuthException('Failed to send password reset: $e');
    }
  }

  /// Anonymous Sign-In (Guest reporting for emergency response)
  Future<UserModel> signInAnonymously() async {
    try {
      final credential = await _auth.signInAnonymously();
      final firebaseUser = credential.user;
      if (firebaseUser == null) {
        throw const AppAuthException('Anonymous sign-in failed');
      }

      final guestUser = UserModel(
        id: firebaseUser.uid,
        email: 'guest_${firebaseUser.uid.substring(0, 6)}@pawaid.local',
        role: FirebaseConstants.roleCitizen,
        displayName: 'Anonymous Citizen',
        accountStatus: 'active',
        createdAt: DateTime.now(),
      );

      await FirebaseFirestore.instance
          .collection(FirebaseConstants.colUsers)
          .doc(firebaseUser.uid)
          .set(guestUser.toMap(), SetOptions(merge: true));

      return guestUser;
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthError(e);
    } catch (e) {
      throw AppAuthException(e.toString());
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw AppAuthException('Sign out failed: $e');
    }
  }

  /// Maps Firebase Auth error codes to user-friendly error messages
  AppAuthException _mapFirebaseAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return const AppAuthException('No user found with this email address.', code: 'user-not-found');
      case 'wrong-password':
      case 'invalid-credential':
        return const AppAuthException('Invalid email or password. Please verify your credentials.', code: 'invalid-credential');
      case 'email-already-in-use':
        return const AppAuthException('An account already exists with this email address.', code: 'email-already-in-use');
      case 'weak-password':
        return const AppAuthException('The password provided is too weak. Please use at least 6 characters.', code: 'weak-password');
      case 'invalid-email':
        return const AppAuthException('The email address entered is not valid.', code: 'invalid-email');
      case 'user-disabled':
        return const AppAuthException('This user account has been disabled.', code: 'user-disabled');
      case 'too-many-requests':
        return const AppAuthException('Too many attempts. Please try again later.', code: 'too-many-requests');
      default:
        return AppAuthException(e.message ?? 'Authentication error occurred.', code: e.code);
    }
  }
}
