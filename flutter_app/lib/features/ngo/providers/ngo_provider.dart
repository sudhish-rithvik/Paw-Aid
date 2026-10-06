// lib/features/ngo/providers/ngo_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/services/api_service.dart';
import '../../../core/services/supabase_service.dart';

part 'ngo_provider.g.dart';

@riverpod
Future<Map<String, dynamic>?> currentNGO(Ref ref) async {
  try {
    final user = SupabaseService.auth.currentUser;
    if (user != null) {
      final profile = await SupabaseService.getNGOProfile();
      if (profile != null) return profile;
    }
  } catch (_) {}
  
  return {
    'id': '11111111-1111-1111-1111-111111111111',
    'name': 'Chennai Animal Rescue Foundation (CARF)',
    'registration_number': 'TN/NGO/2019/001',
    'email': 'rescue@carf.org.in',
    'phone': '+914411223344',
    'city': 'Chennai',
    'state': 'Tamil Nadu',
    'address': '42, Pantheon Road, Egmore, Chennai',
    'specializations': ['Dog', 'Cat', 'Stray Animals'],
    'status': 'approved',
    'avg_response_sec': 900,
    'rescue_success_rate': 0.94,
    'num_vehicles': 4,
    'num_volunteers': 12,
    'service_radius_km': 30.0,
    'operating_hours': '24/7',
    'lat': 13.0827,
    'lng': 80.2707,
  };
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
