// lib/features/admin/screens/admin_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/admin_provider.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(platformStatsDataProvider);
    final pendingNGOsAsync = ref.watch(pendingNGOsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('PAW-AID Admin Portal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Sign Out'),
                  content: const Text('Sign out from Admin Control Panel?'),
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
          await ref.read(platformStatsDataProvider.notifier).refresh();
          await ref.read(pendingNGOsProvider.notifier).refresh();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Pending Verification Banner Alert
              pendingNGOsAsync.when(
                data: (ngos) {
                  if (ngos.isEmpty) return const SizedBox.shrink();
                  return Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.15),
                      border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.verified_user_outlined, color: AppColors.warning),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${ngos.length} Pending NGO Registrations',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Awaiting credential review and approval.',
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () => context.go('/admin/verification'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.warning,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          ),
                          child: const Text('REVIEW', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ).animate().shake();
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),

              // KPI Stats Grid
              statsAsync.when(
                data: (stats) {
                  final totalRescued = stats['total_rescued'] ?? 0;
                  final activeNgos = stats['active_ngos'] ?? 0;
                  final pendingCases = stats['pending_cases'] ?? 0;
                  final avgRespSec = stats['avg_response_sec'] ?? 0;
                  final avgRespMin = (avgRespSec / 60.0).toStringAsFixed(1);

                  return GridView.count(
                    shrinkWrap: true,
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.3,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildKpiTile('Rescues Completed', '$totalRescued', AppColors.secondary, Icons.favorite),
                      _buildKpiTile('Active Incidents', '$pendingCases', AppColors.critical, Icons.warning),
                      _buildKpiTile('Registered NGOs', '$activeNgos', AppColors.info, Icons.business),
                      _buildKpiTile('Avg Response Time', '$avgRespMin', AppColors.primary, Icons.timer),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Text('Error loading stats: $err'),
              ).animate().fadeIn(duration: 500.ms),
              const SizedBox(height: 32),

              // Navigation Grid Shortcuts
              Text(
                'Shortcut Console',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildShortCutButton(
                      context,
                      label: 'VERIFY QUEUE',
                      icon: Icons.verified_outlined,
                      onTap: () => context.go('/admin/verification'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildShortCutButton(
                      context,
                      label: 'CASE MONITOR',
                      icon: Icons.cases_outlined,
                      onTap: () => context.go('/admin/cases'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildShortCutButton(
                      context,
                      label: 'CITY HEATMAP',
                      icon: Icons.map_outlined,
                      onTap: () => context.go('/admin/analytics'),
                    ),
                  ),
                ],
              ).animate().slideY(begin: 0.1, duration: 600.ms),
              const SizedBox(height: 32),

              // Overview platform map
              Text(
                'Incident Mapping Overview',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 300,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: FlutterMap(
                    options: const MapOptions(
                      initialCenter: LatLng(13.0827, 80.2707),
                      initialZoom: 11.0,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: ApiConstants.osmTileUrl,
                        userAgentPackageName: 'org.pawaid.app',
                      ),
                    ],
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

  Widget _buildKpiTile(String title, String value, Color color, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShortCutButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Card(
        color: AppColors.surfaceVariant,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Column(
            children: [
              Icon(icon, color: AppColors.primary, size: 24),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
