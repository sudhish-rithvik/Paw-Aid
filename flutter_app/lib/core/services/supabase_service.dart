// lib/core/services/supabase_service.dart
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
export 'dart:typed_data' show Uint8List;

import '../constants/api_constants.dart';

/// Singleton Supabase client wrapper.
class SupabaseService {
  SupabaseService._();

  static SupabaseClient get client => Supabase.instance.client;
  static GoTrueClient get auth => Supabase.instance.client.auth;
  static SupabaseStorageClient get storage => Supabase.instance.client.storage;

  /// Upload raw bytes to a Supabase Storage bucket.
  /// Returns the public URL on success, or null on failure.
  static Future<String?> uploadFile({
    required String bucket,
    required String path,
    required List<int> bytes,
    String contentType = 'image/jpeg',
  }) async {
    try {
      await storage.from(bucket).uploadBinary(
            path,
            bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
            fileOptions: FileOptions(contentType: contentType, upsert: true),
          );
      return getPublicUrl(bucket, path);
    } catch (e) {
      return null;
    }
  }

  /// Get the public URL for a file in a Supabase Storage bucket.
  static String getPublicUrl(String bucket, String path) {
    return storage.from(bucket).getPublicUrl(path);
  }

  /// Get the current authenticated user's profile from the `profiles` table.
  static Future<Map<String, dynamic>?> getUserProfile() async {
    final user = auth.currentUser;
    if (user == null) return null;
    try {
      final response = await client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();
      return response;
    } catch (e) {
      return null;
    }
  }

  /// Upsert the FCM token in the `profiles` table.
  static Future<void> updateFcmToken(String token) async {
    final user = auth.currentUser;
    if (user == null) return;
    try {
      await client.from('profiles').upsert({
        'id': user.id,
        'fcm_token': token,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  /// Get NGO profile for the current user.
  static Future<Map<String, dynamic>?> getNGOProfile() async {
    final user = auth.currentUser;
    if (user == null) return null;
    try {
      final response = await client
          .from('ngos')
          .select()
          .eq('contact_user_id', user.id)
          .maybeSingle();
      return response;
    } catch (e) {
      return null;
    }
  }
}
