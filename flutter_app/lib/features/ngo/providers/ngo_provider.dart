// lib/features/ngo/providers/ngo_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/services/api_service.dart';
import '../../../core/services/supabase_service.dart';

part 'ngo_provider.g.dart';

@riverpod
Future<Map<String, dynamic>?> currentNGO(Ref ref) async {
  final user = SupabaseService.auth.currentUser;
  if (user == null) return null;
  
  // Fetch NGO profile where contact_user_id (or similar refs) match
  // In the DB: ngos table has contact email, and we can match by email or profile ref.
  // Wait, let's see. The backend supabase query in supabase_service matches by 'contact_user_id'.
  // Let's call SupabaseService.getNGOProfile()
  return SupabaseService.getNGOProfile();
}

@riverpod
class RescueQueue extends _$RescueQueue {
  @override
  Future<List<dynamic>> build() async {
    final ngo = await ref.watch(currentNGOProvider.future);
    if (ngo == null) return [];
    return ApiService.getRescueQueue(ngoId: ngo['id'] as String);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    final ngo = await ref.read(currentNGOProvider.future);
    if (ngo == null) {
      state = const AsyncValue.data([]);
      return;
    }
    state = await AsyncValue.guard(() => ApiService.getRescueQueue(ngoId: ngo['id'] as String));
  }

  Future<void> accept(String caseId) async {
    await ApiService.acceptCase(caseId);
    await refresh();
  }

  Future<void> updateCaseStatus(
    String caseId,
    String status, {
    List<int>? imageBytes,
    String? notes,
  }) async {
    await ApiService.updateCaseStatus(
      caseId,
      status,
      imageBytes: imageBytes,
      notes: notes,
    );
    await refresh();
  }
}

@riverpod
class NGOAnalyticsData extends _$NGOAnalyticsData {
  @override
  Future<Map<String, dynamic>> build() async {
    final ngo = await ref.watch(currentNGOProvider.future);
    if (ngo == null) return {};
    return ApiService.getAnalytics(ngoId: ngo['id'] as String);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    final ngo = await ref.read(currentNGOProvider.future);
    if (ngo == null) {
      state = const AsyncValue.data({});
      return;
    }
    state = await AsyncValue.guard(() => ApiService.getAnalytics(ngoId: ngo['id'] as String));
  }
}

@riverpod
class NearbyCases extends _$NearbyCases {
  @override
  Future<List<dynamic>> build({required double lat, required double lng, double radius = 25.0}) async {
    return ApiService.getNearbyCases(lat: lat, lng: lng, radiusKm: radius);
  }

  Future<void> refresh({required double lat, required double lng, double radius = 25.0}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => ApiService.getNearbyCases(lat: lat, lng: lng, radiusKm: radius));
  }
}
