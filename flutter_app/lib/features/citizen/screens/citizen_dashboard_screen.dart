// lib/features/citizen/screens/citizen_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/report_provider.dart';

class CitizenDashboardScreen extends ConsumerWidget {
  const CitizenDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);
    final reportsAsync = ref.watch(myReportsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('PAW-AID Citizen'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Sign Out'),
                  content: const Text('Are you sure you want to sign out?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('CANCEL'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('SIGN OUT', style: TextStyle(color: AppColors.critical)),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await ref.read(authNotifierProvider.notifier).signOut();
                if (context.mounted) {
                  context.go('/login');
                }
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(myReportsProvider.notifier).refresh(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Greeting Section
              profileAsync.when(
                data: (profile) {
                  final name = profile?['display_name'] ?? 'Citizen';
                  return Text(
                    'Welcome back,\n$name',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                  );
                },
                loading: () => const Text('Loading user...'),
                error: (_, __) => const Text('Hello Citizen!'),
              ).animate().fadeIn(duration: 500.ms),
              const SizedBox(height: 24),

              // Report Animal CTA Card
              Card(
                clipBehavior: Clip.antiAlias,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primary,
                        Color(0xFFE0531D),
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.report_problem, size: 28, color: Colors.white),
                          SizedBox(width: 12),
                          Text(
                            'Report Injured Animal',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Report an animal in distress instantly. AI determines the injury severity and routes details to the nearest rescue team.',
                        style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () => context.push('/report'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.primary,
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('REPORT NOW'),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward, size: 16),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate().slideY(begin: 0.1, duration: 600.ms),
              const SizedBox(height: 32),

              // Recent Reports Section Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'My Reports',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  TextButton(
                    onPressed: () => context.push('/citizen/reports'),
                    child: const Text('View All'),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Reports list
              reportsAsync.when(
                data: (reports) {
                  if (reports.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      alignment: Alignment.center,
                      child: Column(
                        children: [
                          const Icon(Icons.history, size: 48, color: AppColors.textHint),
                          const SizedBox(height: 12),
                          const Text(
                            'No reports submitted yet.',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton(
                            onPressed: () => context.push('/report'),
                            child: const Text('MAKE FIRST REPORT'),
                          ),
                        ],
                      ),
                    );
                  }

                  // Take only top 3 for dashboard
                  final recentReports = reports.take(3).toList();

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: recentReports.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (ctx, index) {
                      final item = recentReports[index] as Map<String, dynamic>;
                      return _buildReportCard(context, item);
                    },
                  );
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 30),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (err, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 30),
                    child: Text('Error loading reports: $err',
                        style: const TextStyle(color: AppColors.critical)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportCard(BuildContext context, Map<String, dynamic> item) {
    final caseId = item['id'] as String;
    final status = item['status'] as String? ?? 'pending';
    final priority = item['priority_level'] as String? ?? 'medium';
    final address = item['address'] as String? ?? 'Unknown location';
    
    // AI Analysis fields
    final animal = item['animal'] as String? ?? 'Animal';
    
    // Status color
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
        ? DateFormat.yMMMd().format(DateTime.parse(item['created_at']))
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
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    dateStr,
                    style: const TextStyle(color: AppColors.textHint, fontSize: 11),
                  ),
                  const Row(
                    children: [
                      Text('Track Rescue', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_ios, size: 10, color: AppColors.primary),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
