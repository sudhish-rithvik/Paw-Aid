// lib/features/ngo/screens/ngo_analytics_screen.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../providers/ngo_provider.dart';

class NGOAnalyticsScreen extends ConsumerWidget {
  const NGOAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsAsync = ref.watch(nGOAnalyticsDataProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('NGO Performance Analytics'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(nGOAnalyticsDataProvider.notifier).refresh(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24.0),
          child: analyticsAsync.when(
            data: (stats) {
              final active = stats['active_cases'] ?? 0;
              final completed = stats['completed_cases'] ?? 0;
              final List<dynamic> historical = stats['historical'] ?? [];

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // KPI Stats Grid
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatTile(
                          context,
                          title: 'Active Missions',
                          value: '$active',
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatTile(
                          context,
                          title: 'Rescues Completed',
                          value: '$completed',
                          color: AppColors.secondary,
                        ),
                      ),
                    ],
                  ).animate().fadeIn().slideY(begin: 0.05),
                  const SizedBox(height: 32),

                  // Completed rescues trend
                  Text(
                    'Rescue Trend (Historical)',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 240,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: historical.isEmpty
                            ? const Center(child: Text('No historical data available yet', style: TextStyle(color: AppColors.textHint)))
                            : LineChart(
                                _buildLineChartData(historical),
                              ),
                      ),
                    ),
                  ).animate().fadeIn(delay: 150.ms),
                  const SizedBox(height: 32),

                  // Response time histogram
                  Text(
                    'Average Response Time (mins)',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 240,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: historical.isEmpty
                            ? const Center(child: Text('No historical data available yet', style: TextStyle(color: AppColors.textHint)))
                            : BarChart(
                                _buildBarChartData(historical),
                              ),
                      ),
                    ),
                  ).animate().fadeIn(delay: 300.ms),
                  const SizedBox(height: 24),
                ],
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 100),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (err, _) => Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 100),
                child: Text('Error loading analytics: $err', style: const TextStyle(color: AppColors.critical)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatTile(
    BuildContext context, {
    required String title,
    required String value,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 10),
            Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  LineChartData _buildLineChartData(List<dynamic> historical) {
    final spots = <FlSpot>[];
    // Reverse historical list to make it chronological
    final chron = historical.reversed.toList();
    for (int i = 0; i < chron.length; i++) {
      final val = chron[i]['completed_count'] as num? ?? 0;
      spots.add(FlSpot(i.toDouble(), val.toDouble()));
    }

    return LineChartData(
      gridData: const FlGridData(show: false),
      titlesData: const FlTitlesData(
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(
        show: true,
        border: const Border(
          bottom: BorderSide(color: AppColors.divider, width: 1),
          left: BorderSide(color: AppColors.divider, width: 1),
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: AppColors.secondary,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: true),
          belowBarData: BarAreaData(
            show: true,
            color: AppColors.secondary.withOpacity(0.15),
          ),
        ),
      ],
    );
  }

  BarChartData _buildBarChartData(List<dynamic> historical) {
    final chron = historical.reversed.toList();
    final List<BarChartGroupData> groups = [];

    for (int i = 0; i < chron.length; i++) {
      final seconds = chron[i]['avg_response_sec'] as num? ?? 0;
      final minutes = seconds / 60.0;
      groups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: minutes,
              color: AppColors.primary,
              width: 12,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      );
    }

    return BarChartData(
      gridData: const FlGridData(show: false),
      titlesData: const FlTitlesData(
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(
        show: true,
        border: const Border(
          bottom: BorderSide(color: AppColors.divider, width: 1),
          left: BorderSide(color: AppColors.divider, width: 1),
        ),
      ),
      barGroups: groups,
    );
  }
}
