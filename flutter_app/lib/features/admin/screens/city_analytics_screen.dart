// lib/features/admin/screens/city_analytics_screen.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/services/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../widgets/city_heatmap.dart';

class CityAnalyticsScreen extends ConsumerStatefulWidget {
  const CityAnalyticsScreen({super.key});

  @override
  ConsumerState<CityAnalyticsScreen> createState() => _CityAnalyticsScreenState();
}

class _CityAnalyticsScreenState extends ConsumerState<CityAnalyticsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _heatmapPoints = [];
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _fetchAnalyticsData();
  }

  Future<void> _fetchAnalyticsData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final heatmapData = await ApiService.getHeatmapData();
      final statsData = await ApiService.getPlatformStats();

      setState(() {
        _heatmapPoints = heatmapData;
        _stats = statsData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('City Analytics')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: AppColors.critical),
                const SizedBox(height: 16),
                Text('Error loading analytics: $_errorMessage', textAlign: TextAlign.center),
                const SizedBox(height: 24),
                ElevatedButton(onPressed: _fetchAnalyticsData, child: const Text('RETRY')),
              ],
            ),
          ),
        ),
      );
    }

    final totalCases = _stats['total_cases'] ?? 0;
    final totalRescued = _stats['total_rescued'] ?? 0;
    final activeCases = _stats['pending_cases'] ?? 0;

    // Severity breakdown
    final critical = _stats['critical_cases'] ?? 0;
    final high = _stats['high_cases'] ?? 0;
    final medium = _stats['medium_cases'] ?? 0;
    final low = _stats['low_cases'] ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('City-Wide Rescue Analytics'),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchAnalyticsData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hotspots map title
              const Text(
                'Injury Density Hotspots Map',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
              ),
              const SizedBox(height: 12),

              // Heatmap using flutter_map_heatmap
              SizedBox(
                height: 280,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CityHeatmap(
                    hotspots: List<Map<String, dynamic>>.from(_heatmapPoints),
                    initialCenter: const LatLng(13.0827, 80.2707),
                    initialZoom: 11.5,
                  ),
                ),
              ).animate().fadeIn(duration: 400.ms),
              const SizedBox(height: 32),

              // Severity Breakdown Pie Chart
              const Text(
                'Incident Severity Breakdown',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 200,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: PieChart(
                            PieChartData(
                              sectionsSpace: 4,
                              centerSpaceRadius: 40,
                              sections: [
                                if (critical > 0)
                                  PieChartSectionData(color: AppColors.critical, value: critical.toDouble(), title: '$critical', radius: 40, titleStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12)),
                                if (high > 0)
                                  PieChartSectionData(color: AppColors.high, value: high.toDouble(), title: '$high', radius: 40, titleStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12)),
                                if (medium > 0)
                                  PieChartSectionData(color: AppColors.medium, value: medium.toDouble(), title: '$medium', radius: 40, titleStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12)),
                                if (low > 0)
                                  PieChartSectionData(color: AppColors.low, value: low.toDouble(), title: '$low', radius: 40, titleStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                        // Legend
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLegendItem('Critical', AppColors.critical),
                            const SizedBox(height: 6),
                            _buildLegendItem('High', AppColors.high),
                            const SizedBox(height: 6),
                            _buildLegendItem('Medium', AppColors.medium),
                            const SizedBox(height: 6),
                            _buildLegendItem('Low', AppColors.low),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ).animate().fadeIn(delay: 150.ms),
              const SizedBox(height: 32),

              // Platform metrics numbers
              const Text(
                'Platform Metrics Summary',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      _buildSummaryRow('Total Cases Logged', '$totalCases', Icons.assessment_outlined),
                      const Divider(height: 24),
                      _buildSummaryRow('Total Animals Rescued', '$totalRescued', Icons.favorite_border),
                      const Divider(height: 24),
                      _buildSummaryRow('Active Rescue Operations', '$activeCases', Icons.run_circle_outlined),
                    ],
                  ),
                ),
              ).animate().fadeIn(delay: 300.ms),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 16),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const Spacer(),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
      ],
    );
  }
}
