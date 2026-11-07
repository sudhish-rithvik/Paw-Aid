// lib/core/services/realtime_service.dart
import 'dart:async';
import 'report_service.dart';

/// Real-Time Synchronization Service
/// Provides reactive streams for rescue cases and notifications.
class RealtimeService {
  RealtimeService._();

  static final Map<String, StreamController<Map<String, dynamic>>> _caseControllers = {};
  static final StreamController<Map<String, dynamic>> _newReportController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// Subscribe to live status changes of a rescue case
  static Stream<Map<String, dynamic>> subscribeToCaseUpdates(String caseId) {
    if (!_caseControllers.containsKey(caseId)) {
      _caseControllers[caseId] = StreamController<Map<String, dynamic>>.broadcast();

      Timer.periodic(const Duration(seconds: 8), (timer) async {
        if (_caseControllers[caseId]?.isClosed ?? true) {
          timer.cancel();
          return;
        }
        try {
          final updatedCase = await ReportService.getReport(caseId);
          _caseControllers[caseId]?.add(updatedCase);
        } catch (_) {}
      });
    }

    return _caseControllers[caseId]!.stream;
  }

  /// Stream of newly created animal rescue reports
  static Stream<Map<String, dynamic>> get onNewReportAvailable => _newReportController.stream;

  /// Notify subscribers of a newly created report
  static void notifyNewReport(Map<String, dynamic> report) {
    _newReportController.add(report);
  }

  /// Dispose stream for a case
  static void unsubscribeFromCase(String caseId) {
    _caseControllers[caseId]?.close();
    _caseControllers.remove(caseId);
  }
}
