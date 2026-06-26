// lib/features/admin/providers/admin_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/services/api_service.dart';

part 'admin_provider.g.dart';

@riverpod
class PendingNGOs extends _$PendingNGOs {
  @override
  Future<List<dynamic>> build() async {
    return ApiService.getPendingNGOs();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => ApiService.getPendingNGOs());
  }
}

@riverpod
class PlatformStatsData extends _$PlatformStatsData {
  @override
  Future<Map<String, dynamic>> build() async {
    return ApiService.getPlatformStats();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => ApiService.getPlatformStats());
  }
}

@riverpod
class NGOVerificationNotifier extends _$NGOVerificationNotifier {
  @override
  FutureOr<void> build() {}

  Future<void> approve(String ngoId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await ApiService.approveNGO(ngoId);
      ref.invalidate(pendingNGOsProvider);
    });
  }

  Future<void> reject(String ngoId, String reason) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await ApiService.rejectNGO(ngoId, reason);
      ref.invalidate(pendingNGOsProvider);
    });
  }
}
