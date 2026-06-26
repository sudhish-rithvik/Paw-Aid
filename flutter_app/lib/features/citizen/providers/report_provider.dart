// lib/features/citizen/providers/report_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/services/api_service.dart';
import '../../../core/services/supabase_service.dart';

part 'report_provider.g.dart';

@riverpod
class MyReports extends _$MyReports {
  @override
  Future<List<dynamic>> build() async {
    final session = SupabaseService.auth.currentSession;
    if (session == null) return [];
    return ApiService.getMyReports();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => ApiService.getMyReports());
  }
}

@riverpod
class CaseStatusNotifier extends _$CaseStatusNotifier {
  @override
  Future<Map<String, dynamic>> build(String caseId) async {
    return ApiService.getCaseStatus(caseId);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => ApiService.getCaseStatus(caseId));
  }
}
