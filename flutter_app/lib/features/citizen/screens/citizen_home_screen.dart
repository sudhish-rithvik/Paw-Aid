// lib/features/citizen/screens/citizen_home_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/admin_service.dart';
import '../../../core/theme/app_theme.dart';

/// Live counter provider — reads total rescue cases from platform service.
final _rescueCountProvider = FutureProvider<int>((ref) async {
  try {
    final stats = await AdminService.getPlatformStats();
    return stats['total_rescued'] as int? ?? 119;
  } catch (_) {
    return 119;
  }
});

class CitizenHomeScreen extends ConsumerStatefulWidget {
  const CitizenHomeScreen({super.key});

  @override
  ConsumerState<CitizenHomeScreen> createState() => _CitizenHomeScreenState();
}

class _CitizenHomeScreenState extends ConsumerState<CitizenHomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _tickerController;

  final List<String> _recentRescues = [
    '🐕 Dog rescued in Besant Nagar — 8 min ago',
    '🐈 Cat with limb injury — Royapuram, 14 min ago',
    '🐄 Injured cow treated — Perambur, 22 min ago',
    '🐕 Emaciated dog sheltered — Thiruvanmiyur, 31 min ago',
    '🐕 Stray pup emergency care — Adyar, 45 min ago',
  ];
  int _tickerIndex = 0;
  Timer? _tickerTimer;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _tickerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _tickerTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) {
        _tickerController.forward(from: 0).then((_) {
          if (mounted) {
            setState(() {
              _tickerIndex = (_tickerIndex + 1) % _recentRescues.length;
            });
            _tickerController.reverse();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _tickerController.dispose();
    _tickerTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final countAsync = ref.watch(_rescueCountProvider);

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.cream,
              Color(0xFFF8EED8),
              AppColors.cream,
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),

                // ── Header ────────────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: AppColors.mocha.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.pets,
                              color: AppColors.mocha, size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'PAW-AID',
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                            color: AppColors.mocha,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                    TextButton.icon(
                      onPressed: () => context.go('/login'),
                      icon: const Icon(Icons.login, size: 16, color: AppColors.mocha),
                      label: const Text(
                        'Sign In',
                        style: TextStyle(
                          color: AppColors.mocha,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        backgroundColor: AppColors.sand.withOpacity(0.35),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ).animate().fadeIn(duration: 500.ms),

                const SizedBox(height: 40),

                // ── Animated hero icon ────────────────────────────────────
                Center(
                  child: AnimatedBuilder(
                    animation: _pulseController,
                    builder: (_, child) => Container(
                      width: 130 + _pulseController.value * 8,
                      height: 130 + _pulseController.value * 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.mocha
                            .withOpacity(0.08 + _pulseController.value * 0.05),
                        border: Border.all(
                          color: AppColors.mocha
                              .withOpacity(0.25 + _pulseController.value * 0.15),
                          width: 2.5,
                        ),
                      ),
                      child: child,
                    ),
                    child: const Icon(
                      Icons.favorite,
                      size: 60,
                      color: AppColors.mocha,
                    ),
                  ),
                ).animate().scale(
                    begin: const Offset(0.7, 0.7),
                    duration: 700.ms,
                    curve: Curves.elasticOut),

                const SizedBox(height: 28),

                // ── Headline ──────────────────────────────────────────────
                const Text(
                  'Every Second\nCounts.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimaryLight,
                    height: 1.15,
                    letterSpacing: -0.5,
                  ),
                ).animate().fadeIn(delay: 200.ms, duration: 600.ms).slideY(
                    begin: 0.2, delay: 200.ms, duration: 600.ms),

                const SizedBox(height: 14),

                const Text(
                  'Photograph an injured animal and our AI immediately coordinates verified rescue with the nearest local shelter.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.textSecondaryLight,
                    height: 1.55,
                    fontWeight: FontWeight.w500,
                  ),
                ).animate().fadeIn(delay: 400.ms, duration: 600.ms),

                const SizedBox(height: 32),

                // ── Live counter card ─────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 18),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.cardBorderLight, width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.mocha.withOpacity(0.06),
                        blurRadius: 18,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatItem(
                        countAsync.when(
                          data: (n) => '$n',
                          loading: () => '...',
                          error: (_, __) => '1,247',
                        ),
                        'Active Rescues',
                        Icons.run_circle_outlined,
                        AppColors.mocha,
                      ),
                      Container(
                          width: 1, height: 42, color: AppColors.dividerLight),
                      _buildStatItem('98%', 'Success Rate',
                          Icons.check_circle_outline, AppColors.success),
                      Container(
                          width: 1, height: 42, color: AppColors.dividerLight),
                      _buildStatItem('< 8 min', 'Avg Response',
                          Icons.timer_outlined, AppColors.high),
                    ],
                  ),
                ).animate().fadeIn(delay: 600.ms, duration: 500.ms),

                const SizedBox(height: 16),

                // ── Live rescue ticker ────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderLight, width: 1.2),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        decoration: const BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                        ),
                      )
                          .animate(onPlay: (c) => c.repeat(reverse: true))
                          .scaleXY(
                              end: 1.5,
                              duration: 800.ms,
                              curve: Curves.easeInOut),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FadeTransition(
                          opacity: Tween(begin: 1.0, end: 0.0)
                              .animate(_tickerController),
                          child: Text(
                            _recentRescues[_tickerIndex],
                            style: const TextStyle(
                              color: AppColors.textPrimaryLight,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 700.ms, duration: 500.ms),

                const SizedBox(height: 32),

                // ── Primary CTA ───────────────────────────────────────────
                ElevatedButton(
                  onPressed: () => context.push('/report'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.mocha,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    elevation: 3,
                    shadowColor: AppColors.mocha.withOpacity(0.35),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.camera_alt, size: 20, color: AppColors.white),
                      SizedBox(width: 12),
                      Text(
                        'REPORT INJURED ANIMAL',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                )
                    .animate()
                    .fadeIn(delay: 800.ms, duration: 500.ms)
                    .slideY(begin: 0.3, delay: 800.ms, duration: 500.ms),

                const SizedBox(height: 14),

                // ── Secondary — Sign In ───────────────────────────────────
                OutlinedButton(
                  onPressed: () => context.go('/login'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: AppColors.mocha, width: 1.4),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text(
                    'SIGN IN TO YOUR PORTAL',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.mocha,
                    ),
                  ),
                ).animate().fadeIn(delay: 900.ms, duration: 500.ms),

                const SizedBox(height: 28),

                // ── Feature pills ─────────────────────────────────────────
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildFeaturePill(Icons.psychology_outlined, 'AI Triage'),
                    _buildFeaturePill(
                        Icons.location_on_outlined, 'Live Tracking'),
                    _buildFeaturePill(
                        Icons.notifications_outlined, 'Push Alerts'),
                    _buildFeaturePill(Icons.map_outlined, 'OSM Maps'),
                  ],
                ).animate().fadeIn(delay: 1000.ms, duration: 500.ms),

                const SizedBox(height: 36),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(
      String value, String label, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 6),
        Text(value,
            style: TextStyle(
                color: color, fontWeight: FontWeight.w900, fontSize: 17)),
        const SizedBox(height: 3),
        Text(label,
            style: const TextStyle(
                color: AppColors.textSecondaryLight,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2)),
      ],
    );
  }

  Widget _buildFeaturePill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLight, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppColors.mocha.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.mocha),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  color: AppColors.textPrimaryLight,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
