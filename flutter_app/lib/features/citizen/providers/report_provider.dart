// lib/features/citizen/providers/report_provider.dart
import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/services/api_service.dart';
import '../../../core/services/report_service.dart';

part 'report_provider.g.dart';

@riverpod
class MyReports extends _$MyReports {
  @override
  Future<List<dynamic>> build() async {
    return ApiService.getMyReports();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => ApiService.getMyReports());
  }
}

@riverpod
class CaseStatusNotifier extends _$CaseStatusNotifier {
  StreamSubscription? _subscription;

  @override
  Future<Map<String, dynamic>> build(String caseId) async {
    // Listen to reactive Cloud Firestore stream updates
    _subscription = ReportService.watchReport(caseId).listen((data) {
      state = AsyncValue.data(data);
    });

    ref.onDispose(() {
      _subscription?.cancel();
    });

    return ApiService.getCaseStatus(caseId);
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(() => ApiService.getCaseStatus(caseId));
  }
}
