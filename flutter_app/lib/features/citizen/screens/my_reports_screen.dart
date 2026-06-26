// lib/features/citizen/screens/my_reports_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../providers/report_provider.dart';

class MyReportsScreen extends ConsumerWidget {
  const MyReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsAsync = ref.watch(myReportsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Rescue Reports'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(myReportsProvider.notifier).refresh(),
        child: reportsAsync.when(
          data: (reports) {
            if (reports.isEmpty) {
              return ListView(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 100, horizontal: 24),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.history_toggle_off, size: 64, color: AppColors.textHint),
                        const SizedBox(height: 16),
                        const Text(
                          'No reports found',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'You haven\'t reported any injured animals yet.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () => context.push('/report'),
                          child: const Text('REPORT INJURED ANIMAL'),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            final activeReports = reports
                .where((item) =>
                    item['status'] != 'completed' && item['status'] != 'closed')
                .toList();
            final completedReports = reports
                .where((item) =>
                    item['status'] == 'completed' || item['status'] == 'closed')
                .toList();

            return DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  const TabBar(
                    tabs: [
                      Tab(text: 'ACTIVE RESCUES'),
                      Tab(text: 'HISTORY'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildReportsList(context, activeReports, 'No active rescues'),
                        _buildReportsList(context, completedReports, 'No completed rescues in history'),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => ListView(
            children: [
              Container(
                padding: const EdgeInsets.all(40),
                alignment: Alignment.center,
                child: Text('Error loading reports: $err', style: const TextStyle(color: AppColors.critical)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportsList(BuildContext context, List<dynamic> list, String emptyMessage) {
    if (list.isEmpty) {
      return Center(
        child: Text(
          emptyMessage,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (ctx, index) {
        final item = list[index] as Map<String, dynamic>;
        final caseId = item['id'] as String;
        final status = item['status'] as String? ?? 'pending';
        final priority = item['priority_level'] as String? ?? 'medium';
        final address = item['address'] as String? ?? 'Unknown location';
        final animal = item['animal'] as String? ?? 'Animal';

        final statusColor = switch (status) {
          'pending' => AppColors.warning,
          'accepted' => AppColors.info,
          'dispatched' => AppColors.info,
          'animal_picked' => AppColors.primary,
          'vet_treatment' => AppColors.primary,
          'recovery' => AppColors.secondary,
          'completed' => AppColors.success,
          _ => AppColors.textSecondary,
        };

        final priorityColor = switch (priority) {
          'critical' => AppColors.critical,
          'high' => AppColors.high,
          'medium' => AppColors.medium,
          'low' => AppColors.low,
          _ => AppColors.textHint,
        };

        final dateStr = item['created_at'] != null
            ? DateFormat.yMMMd().add_jm().format(DateTime.parse(item['created_at']))
            : '';

        return InkWell(
          onTap: () => context.push('/track/$caseId'),
          borderRadius: BorderRadius.circular(12),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: priorityColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: priorityColor.withOpacity(0.3)),
                            ),
                            child: Text(
                              priority.toUpperCase(),
                              style: TextStyle(
                                color: priorityColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            animal.toUpperCase(),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                      Text(
                        status.replaceAll('_', ' ').toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        dateStr,
                        style: const TextStyle(color: AppColors.textHint, fontSize: 11),
                      ),
                      const Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.primary),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
