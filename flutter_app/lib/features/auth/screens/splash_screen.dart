// lib/features/auth/screens/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_theme.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    // Wait for the animation to play
    await Future.delayed(const Duration(milliseconds: 2500));
    if (!mounted) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final bypassRole = prefs.getString('bypass_role');
      if (bypassRole != null) {
        _navigateByRole(bypassRole);
      } else {
        final user = await AuthService.getCurrentUser();
        if (user != null) {
          _navigateByRole(user.role);
        } else {
          context.go('/login');
        }
      }
    } catch (_) {
      if (mounted) {
        context.go('/login');
      }
    }
  }

  void _navigateByRole(String role) {
    switch (role) {
      case 'admin':
        context.go('/admin/dashboard');
        break;
      case 'ngo_staff':
        context.go('/ngo/dashboard');
        break;
      default:
        context.go('/citizen/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainContentPosition(),
          children: [
            // Glow effect behind the paw
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 50,
                        spreadRadius: 20,
                      ),
                    ],
                  ),
                ),
                // Paw icon
                Container(
                  width: 110,
                  height: 110,
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.pets,
                      size: 64,
                      color: AppColors.primary,
                    ),
                  ),
                )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scale(
                      begin: const Offset(0.92, 0.92),
                      end: const Offset(1.06, 1.06),
                      duration: 1200.ms,
                      curve: Curves.easeInOut,
                    ),
              ],
            ),
            const SizedBox(height: 32),

            // App title
            Text(
              'PAW-AID',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                  ),
            )
                .animate()
                .fadeIn(duration: 600.ms, delay: 200.ms)
                .slideY(begin: 0.3, end: 0, duration: 600.ms, curve: Curves.easeOut),

            const SizedBox(height: 10),

            // Subtitle chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                'AI EMERGENCY RESCUE NETWORK',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
              ),
            )
                .animate()
                .fadeIn(duration: 600.ms, delay: 400.ms)
                .scale(begin: const Offset(0.85, 0.85), end: const Offset(1, 1), duration: 600.ms),

            const SizedBox(height: 48),

            // Subtle loading indicator
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.primary.withValues(alpha: 0.7),
                ),
              ),
            ).animate().fadeIn(duration: 400.ms, delay: 800.ms),
          ],
        ),
      ),
    );
  }
}

MainAxisAlignment MainContentPosition() => MainAxisAlignment.center;
