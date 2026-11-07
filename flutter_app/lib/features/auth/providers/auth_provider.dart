// lib/features/auth/providers/auth_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/services/auth_service.dart';

export '../../../core/services/auth_service.dart' show AuthUser;

part 'auth_provider.g.dart';

@riverpod
class AuthNotifier extends _$AuthNotifier {
  @override
  AsyncValue<AuthUser?> build() {
    return const AsyncValue.data(null);
  }

  /// Sign in with email and password via authentication service.
  Future<AuthUser> signIn(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final user = await AuthService.signIn(email: email, password: password);
      state = AsyncValue.data(user);
      ref.invalidate(userProfileProvider);
      return user;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Sign in with predefined role accounts for instant role-switching.
  Future<AuthUser> signInWithRole(String role) async {
    state = const AsyncValue.loading();
    try {
      final user = await AuthService.signInWithRole(role);
      state = AsyncValue.data(user);
      ref.invalidate(userProfileProvider);
      return user;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Register a new citizen account in authentication service.
  Future<AuthUser> signUp({
    required String email,
    required String password,
    required String displayName,
    String? phone,
    String role = 'citizen',
  }) async {
    state = const AsyncValue.loading();
    try {
      final user = await AuthService.signUp(
        email: email,
        password: password,
        displayName: displayName,
        phone: phone,
        role: role,
      );
      state = AsyncValue.data(user);
      ref.invalidate(userProfileProvider);
      return user;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Send password reset email
  Future<void> sendPasswordReset(String email) async {
    await AuthService.sendPasswordResetEmail(email);
  }

  /// Sign out the current user.
  Future<void> signOut() async {
    state = const AsyncValue.loading();
    try {
      await AuthService.signOut();
      ref.invalidate(userProfileProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Update the FCM token for push notifications.
  Future<void> updateFcmToken(String token) async {
    await AuthService.updateFcmToken(token);
  }

  /// Query the user's role from user profile.
  Future<String> getUserRole() async {
    final user = await AuthService.getCurrentUser();
    return user?.role ?? 'citizen';
  }
}

@riverpod
Future<Map<String, dynamic>?> userProfile(Ref ref) async {
  final user = await AuthService.getCurrentUser();
  if (user != null) {
    return user.toMap();
  }
  return {
    'id': '00000000-0000-0000-0000-000000000003',
    'email': 'citizen@pawaid.com',
    'role': 'citizen',
    'display_name': 'Priya Ramesh (Animal Lover)',
    'phone': '+919876543210',
    'accountStatus': 'active',
  };
}

@riverpod
bool isAuthenticated(Ref ref) {
  final authState = ref.watch(authNotifierProvider);
  return authState.valueOrNull != null;
}

@riverpod
String userRole(Ref ref) {
  final profileAsync = ref.watch(userProfileProvider);
  return profileAsync.valueOrNull?['role'] as String? ?? 'citizen';
}

@riverpod
String userAccountStatus(Ref ref) {
  final profileAsync = ref.watch(userProfileProvider);
  return profileAsync.valueOrNull?['accountStatus'] as String? ?? 'active';
}
