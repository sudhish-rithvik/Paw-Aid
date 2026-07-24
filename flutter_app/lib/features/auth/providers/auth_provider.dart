// lib/features/auth/providers/auth_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';

part 'auth_provider.g.dart';

@riverpod
class AuthNotifier extends _$AuthNotifier {
  @override
  AsyncValue<User?> build() {
    final sub = SupabaseService.auth.onAuthStateChange.listen((data) {
      state = AsyncValue.data(data.session?.user);
    });
    ref.onDispose(sub.cancel);
    return AsyncValue.data(SupabaseService.auth.currentUser);
  }

  /// Sign in with email and password.
  Future<void> signIn(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      await SupabaseService.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      state = AsyncValue.data(SupabaseService.auth.currentUser);
    } catch (e) {
      // Local demo mode fallback
      state = const AsyncValue.data(null);
    }
  }

  /// Sign in anonymously and assign a specific role (Bypasses email/password login).
  Future<void> signInWithRole(String role) async {
    state = const AsyncValue.loading();
    try {
      final response = await SupabaseService.auth.signInAnonymously();
      final user = response.user;
      
      if (user != null) {
        try {
          await SupabaseService.client.from('profiles').upsert({
            'id': user.id,
            'display_name': 'Demo ${role == 'ngo_staff' ? 'NGO Staff' : role == 'admin' ? 'Admin' : 'Citizen'}',
            'role': role,
          });
        } catch (_) {}
      }
      state = AsyncValue.data(user);
    } catch (e) {
      // Local demo mode fallback
      state = const AsyncValue.data(null);
    }
  }

  /// Register a new citizen account.
  Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
    String? phone,
  }) async {
    state = const AsyncValue.loading();
    try {
      final response = await SupabaseService.auth.signUp(
        email: email.trim(),
        password: password,
        data: {
          'display_name': displayName.trim(),
          if (phone != null && phone.isNotEmpty) 'phone': phone.trim(),
          'role': 'citizen',
        },
      );
      // Insert profile row
      if (response.user != null) {
        await SupabaseService.client.from('profiles').upsert({
          'id': response.user!.id,
          'display_name': displayName.trim(),
          if (phone != null && phone.isNotEmpty) 'phone': phone.trim(),
          'role': 'citizen',
          'email': email.trim(),
        });
      }
      state = AsyncValue.data(response.user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Sign out the current user.
  Future<void> signOut() async {
    state = const AsyncValue.loading();
    try {
      await SupabaseService.auth.signOut();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Update the FCM token for push notifications.
  Future<void> updateFcmToken(String token) async {
    await SupabaseService.updateFcmToken(token);
  }

  /// Query the user's role from the profiles table.
  Future<String> getUserRole() async {
    final profile = await SupabaseService.getUserProfile();
    return profile?['role'] as String? ?? 'citizen';
  }
}

@riverpod
Future<Map<String, dynamic>?> userProfile(Ref ref) async {
  final authState = ref.watch(authNotifierProvider);
  final user = authState.valueOrNull;
  if (user == null) return null;
  return SupabaseService.getUserProfile();
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
