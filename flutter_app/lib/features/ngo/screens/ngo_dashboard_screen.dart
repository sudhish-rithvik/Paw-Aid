// lib/features/ngo/screens/ngo_dashboard_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/services/location_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/ngo_provider.dart';

class NGODashboardScreen extends ConsumerStatefulWidget {
  const NGODashboardScreen({super.key});

  @override
  ConsumerState<NGODashboardScreen> createState() => _NGODashboardScreenState();
}

class _NGODashboardScreenState extends ConsumerState<NGODashboardScreen> {
  Timer? _refreshTimer;
  LatLng? _deviceLocation;

  @override
  void initState() {
    super.initState();
    _fetchDeviceLocation();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      ref.read(rescueQueueProvider.notifier).refresh();
      ref.read(nGOAnalyticsDataProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchDeviceLocation() async {
    final loc = await LocationService.getCurrentLocation();
    if (mounted) {
      setState(() {
        _deviceLocation = loc;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ngoAsync = ref.watch(currentNGOProvider);
    final queueAsync = ref.watch(rescueQueueProvider);
    final analyticsAsync = ref.watch(nGOAnalyticsDataProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('NGO Rescue Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Sign Out'),
                  content: const Text('Are you sure you want to sign out from NGO Portal?'),
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
        onRefresh: () async {
          ref.invalidate(currentNGOProvider);
          await ref.read(rescueQueueProvider.notifier).refresh();
          await ref.read(nGOAnalyticsDataProvider.notifier).refresh();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Welcome & Profile Section
              ngoAsync.when(
                data: (ngo) {
                  if (ngo == null) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('Under review. Registration pending verification.', style: TextStyle(color: AppColors.warning)),
                      ),
                    );
                  }
                  return Text(
                    'Welcome,\n${ngo['name']}',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                  );
                },
                loading: () => const Text('Loading profile...'),
                error: (err, _) => Text('Error: $err'),
              ).animate().fadeIn(duration: 400.ms),
              const SizedBox(height: 24),

              // KPI counters
              analyticsAsync.when(
                data: (stats) {
                  final active = stats['active_cases'] ?? 0;
                  final completed = stats['completed_cases'] ?? 0;
                  return Row(
                    children: [
                      Expanded(
                        child: _buildKpiCard(
                          context,
                          title: 'Active Rescues',
                          value: '$active',
                          color: AppColors.primary,
                          icon: Icons.run_circle_outlined,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildKpiCard(
                          context,
                          title: 'Total Rescued',
                          value: '$completed',
                          color: AppColors.secondary,
                          icon: Icons.check_circle_outline,
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const Center(child: LinearProgressIndicator()),
                error: (_, __) => const SizedBox.shrink(),
              ).animate().slideY(begin: 0.1, duration: 500.ms),
              const SizedBox(height: 24),

              // CTA to View Queue
              ElevatedButton.icon(
                onPressed: () => context.go('/ngo/queue'),
                icon: const Icon(Icons.format_list_bulleted, color: Colors.white),
                label: const Text('OPEN RESCUE QUEUE'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppColors.primary,
                ),
              ),
              const SizedBox(height: 24),

              // Live Map Title
              Text(
                'Live Incident Map',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),

              // The Map Card
              SizedBox(
                height: 350,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: queueAsync.when(
                    data: (cases) {
                      final ngo = ngoAsync.valueOrNull;
                      final ngoLat = ngo != null ? ngo['lat'] as double? : null;
                      final ngoLng = ngo != null ? ngo['lng'] as double? : null;
                      
                      final centerLocation = ngoLat != null && ngoLng != null
                          ? LatLng(ngoLat, ngoLng)
                          : _deviceLocation ?? const LatLng(13.0827, 80.2707); // Chennai default

                      final List<Marker> markers = [];

                      // Add NGO Marker
                      if (ngoLat != null && ngoLng != null) {
                        markers.add(
                          Marker(
                            point: LatLng(ngoLat, ngoLng),
                            width: 50,
                            height: 50,
                            child: const Icon(Icons.home_work, color: AppColors.secondary, size: 36),
                          ),
                        );
                      }

                      // Add Cases Markers
                      for (final c in cases) {
                        final lat = c['lat'] as double;
                        final lng = c['lng'] as double;
                        final priority = c['priority_level'] as String? ?? 'medium';
                        final assignedNgoId = c['assigned_ngo_id'] as String?;

                        final isAssignedToUs = ngo != null && assignedNgoId == ngo['id'];
                        final color = isAssignedToUs
                            ? AppColors.secondary // Our assigned cases
                            : (priority == 'critical'
                                ? AppColors.critical
                                : priority == 'high'
                                    ? AppColors.high
                                    : AppColors.medium);

                        markers.add(
                          Marker(
                            point: LatLng(lat, lng),
                            width: 40,
                            height: 40,
                            child: GestureDetector(
                              onTap: () {
                                _showCaseQuickView(context, c, isAssignedToUs);
                              },
                              child: Icon(
                                Icons.location_on,
                                color: color,
                                size: 30,
                              ).animate(onPlay: (c) => c.repeat(reverse: true))
                               .scale(begin: const Offset(0.9, 0.9), end: const Offset(1.1, 1.1), duration: 800.ms),
                            ),
                          ),
                        );
                      }

                      return FlutterMap(
                        options: MapOptions(
                          initialCenter: centerLocation,
                          initialZoom: 12.0,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: ApiConstants.osmTileUrl,
                            userAgentPackageName: 'org.pawaid.app',
                          ),
                          MarkerLayer(markers: markers),
                        ],
                      );
                    },
                    loading: () => Container(
                      color: AppColors.surface,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    error: (err, _) => Container(
                      color: AppColors.surface,
                      child: Center(child: Text('Map error: $err')),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKpiCard(
    BuildContext context, {
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCaseQuickView(BuildContext context, Map<String, dynamic> c, bool isAssigned) {
    final priority = c['priority_level'] as String? ?? 'medium';
    final address = c['address'] as String? ?? 'Unknown location';
    final caseId = c['id'] as String;
    
    // AI details
    final animal = (c['ai_analysis'] as Map?)?['animal'] as String? ?? 'Animal';

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${animal.toUpperCase()} - ${priority.toUpperCase()}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                ),
                Text(
                  isAssigned ? 'ASSIGNED TO YOU' : 'PENDING ACCEPTANCE',
                  style: TextStyle(
                    color: isAssigned ? AppColors.secondary : AppColors.warning,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, color: AppColors.textSecondary, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    address,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                context.push(isAssigned ? '/ngo/active/$caseId' : '/ngo/case/$caseId');
              },
              child: Text(isAssigned ? 'OPEN LIVE MISSION TRACKER' : 'VIEW FULL DETAILS'),
            ),
          ],
        ),
      ),
    );
  }
}
