// lib/features/citizen/providers/report_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  RealtimeChannel? _channel;

  @override
  Future<Map<String, dynamic>> build(String caseId) async {
    // Setup realtime listener
    _channel = SupabaseService.client.channel('public:rescue_cases:id=eq.$caseId');
    _channel!.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'rescue_cases',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'id',
        value: caseId,
      ),
      callback: (PostgresChangePayload payload) {
        refresh();
      },
    ).subscribe();

    ref.onDispose(() {
      _channel?.unsubscribe();
    });

    return ApiService.getCaseStatus(caseId);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => ApiService.getCaseStatus(caseId));
  }
}
