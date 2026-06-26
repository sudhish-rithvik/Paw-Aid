// lib/features/citizen/screens/citizen_home_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';

/// Live counter provider — reads total rescue cases from Supabase.
final _rescueCountProvider = FutureProvider<int>((ref) async {
  try {
    final resp = await SupabaseService.client
        .from('rescue_cases')
        .select('id')
        .neq('status', 'closed');
    return (resp as List).length;
  } catch (_) {
    return 1247; // fallback demo value
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
    '🐕 Dog rescued in Chennai — 8 min ago',
    '🐈 Cat with broken leg — Bengaluru, 14 min ago',
    '🐄 Injured cow on highway — Mumbai, 22 min ago',
    '🦜 Injured bird near park — Delhi, 31 min ago',
    '🐕 Stray pup accident victim — Pune, 45 min ago',
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF070B14),
              AppColors.background,
              Color(0xFF0F1826),
            ],
            stops: [0, 0.5, 1],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),

                // ── Header ────────────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.pets,
                              color: AppColors.primary, size: 22),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'PAW-AID',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: const Text(
                        'Sign In',
                        style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ).animate().fadeIn(duration: 500.ms),

                const SizedBox(height: 48),

                // ── Animated hero icon ────────────────────────────────────
                Center(
                  child: AnimatedBuilder(
                    animation: _pulseController,
                    builder: (_, child) => Container(
                      width: 130 + _pulseController.value * 8,
                      height: 130 + _pulseController.value * 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary
                            .withOpacity(0.08 + _pulseController.value * 0.04),
                        border: Border.all(
                          color: AppColors.primary
                              .withOpacity(0.2 + _pulseController.value * 0.15),
                          width: 2,
                        ),
                      ),
                      child: child,
                    ),
                    child: const Icon(
                      Icons.favorite,
                      size: 60,
                      color: AppColors.primary,
                    ),
                  ),
                ).animate().scale(
                    begin: const Offset(0.7, 0.7),
                    duration: 700.ms,
                    curve: Curves.elasticOut),

                const SizedBox(height: 32),

                // ── Headline ──────────────────────────────────────────────
                const Text(
                  'Every Second\nCounts.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.15,
                    letterSpacing: -0.5,
                  ),
                ).animate().fadeIn(delay: 200.ms, duration: 600.ms).slideY(
                    begin: 0.2, delay: 200.ms, duration: 600.ms),

                const SizedBox(height: 16),

                const Text(
                  'Photograph an injured animal and our AI instantly dispatches the nearest rescue team.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                    height: 1.6,
                  ),
                ).animate().fadeIn(delay: 400.ms, duration: 600.ms),

                const SizedBox(height: 36),

                // ── Live counter card ─────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.cardBorder),
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
                        AppColors.primary,
                      ),
                      Container(
                          width: 1, height: 40, color: AppColors.divider),
                      _buildStatItem('98%', 'Success Rate',
                          Icons.check_circle_outline, AppColors.secondary),
                      Container(
                          width: 1, height: 40, color: AppColors.divider),
                      _buildStatItem('< 8 min', 'Avg Response',
                          Icons.timer_outlined, AppColors.high),
                    ],
                  ),
                ).animate().fadeIn(delay: 600.ms, duration: 500.ms),

                const SizedBox(height: 16),

                // ── Live rescue ticker ────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppColors.secondary.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.secondary,
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
                              color: AppColors.secondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 700.ms, duration: 500.ms),

                const SizedBox(height: 40),

                // ── Primary CTA ───────────────────────────────────────────
                ElevatedButton(
                  onPressed: () => context.push('/report'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.camera_alt, size: 20, color: Colors.white),
                      SizedBox(width: 12),
                      Text(
                        'REPORT INJURED ANIMAL',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
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
                    side: const BorderSide(color: AppColors.border, width: 1),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text(
                    'SIGN IN TO YOUR PORTAL',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ).animate().fadeIn(delay: 900.ms, duration: 500.ms),

                const SizedBox(height: 32),

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

                const SizedBox(height: 40),
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
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 6),
        Text(value,
            style: TextStyle(
                color: color, fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(
                color: AppColors.textHint,
                fontSize: 10,
                letterSpacing: 0.3)),
      ],
    );
  }

  Widget _buildFeaturePill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
