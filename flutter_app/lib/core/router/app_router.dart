// lib/core/router/app_router.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../../features/admin/screens/admin_dashboard_screen.dart';
import '../../features/admin/screens/all_cases_screen.dart';
import '../../features/admin/screens/city_analytics_screen.dart';
import '../../features/admin/screens/ngo_detail_admin_screen.dart';
import '../../features/admin/screens/ngo_verification_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/citizen/screens/citizen_dashboard_screen.dart';
import '../../features/citizen/screens/citizen_home_screen.dart';
import '../../features/citizen/screens/my_reports_screen.dart';
import '../../features/citizen/screens/report_animal_screen.dart';
import '../../features/citizen/screens/track_rescue_screen.dart';
import '../../features/ngo/screens/active_rescue_screen.dart';
import '../../features/ngo/screens/case_detail_screen.dart';
import '../../features/ngo/screens/nearby_rescues_screen.dart';
import '../../features/ngo/screens/ngo_analytics_screen.dart';
import '../../features/ngo/screens/ngo_dashboard_screen.dart';
import '../../features/ngo/screens/ngo_registration_screen.dart';
import '../../features/ngo/screens/rescue_queue_screen.dart';
import '../../features/ngo/screens/stage_updater.dart';
import '../../features/citizen/screens/volunteer_signup.dart';

part 'app_router.g.dart';

@riverpod
GoRouter router(Ref ref) {
  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: true,
    redirect: (context, state) async {
      final session = Supabase.instance.client.auth.currentSession;
      final isLoggedIn = session != null;

      final publicPaths = ['/', '/login', '/register', '/ngo-register', '/report'];
      final isPublic = publicPaths.contains(state.matchedLocation) ||
          state.matchedLocation.startsWith('/track/');

      if (!isLoggedIn && !isPublic) {
        return '/login';
      }

      // If logged in and on splash/login/register, route to correct portal
      if (isLoggedIn &&
          (state.matchedLocation == '/' ||
              state.matchedLocation == '/login' ||
              state.matchedLocation == '/register')) {
        try {
          final profile = await Supabase.instance.client
              .from('profiles')
              .select('role')
              .eq('id', session.user.id)
              .maybeSingle();
          final role = profile?['role'] as String? ?? 'citizen';
          switch (role) {
            case 'admin':
              return '/admin/dashboard';
            case 'ngo_staff':
              return '/ngo/dashboard';
            default:
              return '/citizen/home';
          }
        } catch (_) {
          return '/citizen/home';
        }
      }

      return null;
    },
    routes: [
      // ─── Public ───────────────────────────────────────────────────────────
      GoRoute(path: '/', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(
          path: '/ngo-register',
          builder: (_, __) => const NGORegistrationScreen()),
      GoRoute(
          path: '/report', builder: (_, __) => const ReportAnimalScreen()),
      GoRoute(
        path: '/track/:caseId',
        builder: (_, state) =>
            TrackRescueScreen(caseId: state.pathParameters['caseId']!),
      ),
      GoRoute(
        path: '/volunteer-signup',
        builder: (_, __) => const VolunteerSignupScreen(),
      ),
      GoRoute(
        path: '/ngo/stage/:id',
        builder: (_, state) =>
            StageUpdaterScreen(caseId: state.pathParameters['id']!),
      ),

      // ─── Citizen shell ─────────────────────────────────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (context, routerState, navigationShell) =>
            _CitizenShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/citizen/home',
                builder: (_, __) => const CitizenDashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/citizen/reports',
                builder: (_, __) => const MyReportsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/citizen/notifications',
                builder: (_, __) => const _NotificationsPlaceholderScreen(),
              ),
            ],
          ),
        ],
      ),

      // ─── NGO shell ─────────────────────────────────────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (context, routerState, navigationShell) =>
            _NGOShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/ngo/dashboard',
                builder: (_, __) => const NGODashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/ngo/queue',
                builder: (_, __) => const RescueQueueScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/ngo/nearby',
                builder: (_, __) => const NearbyRescuesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/ngo/analytics',
                builder: (_, __) => const NGOAnalyticsScreen(),
              ),
            ],
          ),
        ],
      ),

      // NGO sub-routes (outside shell)
      GoRoute(
        path: '/ngo/case/:id',
        builder: (_, state) =>
            CaseDetailScreen(caseId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/ngo/active/:id',
        builder: (_, state) =>
            ActiveRescueScreen(caseId: state.pathParameters['id']!),
      ),

      // ─── Admin shell ───────────────────────────────────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (context, routerState, navigationShell) =>
            _AdminShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin/dashboard',
                builder: (_, __) => const AdminDashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin/verification',
                builder: (_, __) => const NGOVerificationScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin/cases',
                builder: (_, __) => const AllCasesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin/analytics',
                builder: (_, __) => const CityAnalyticsScreen(),
              ),
            ],
          ),
        ],
      ),

      // Admin sub-routes (outside shell)
      GoRoute(
        path: '/admin/verification/:id',
        builder: (_, state) =>
            NGODetailAdminScreen(ngoId: state.pathParameters['id']!),
      ),
    ],
  );
}

// ─── Shell Scaffolds ──────────────────────────────────────────────────────────

class _CitizenShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  const _CitizenShell({required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.list_alt_outlined), activeIcon: Icon(Icons.list_alt), label: 'My Reports'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications_outlined), activeIcon: Icon(Icons.notifications), label: 'Alerts'),
        ],
      ),
    );
  }
}

class _NGOShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  const _NGOShell({required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.queue_outlined), activeIcon: Icon(Icons.queue), label: 'Queue'),
          BottomNavigationBarItem(icon: Icon(Icons.near_me_outlined), activeIcon: Icon(Icons.near_me), label: 'Nearby'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart_outlined), activeIcon: Icon(Icons.bar_chart), label: 'Analytics'),
        ],
      ),
    );
  }
}

class _AdminShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  const _AdminShell({required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.admin_panel_settings_outlined), activeIcon: Icon(Icons.admin_panel_settings), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.verified_outlined), activeIcon: Icon(Icons.verified), label: 'Verify'),
          BottomNavigationBarItem(icon: Icon(Icons.cases_outlined), activeIcon: Icon(Icons.cases), label: 'Cases'),
          BottomNavigationBarItem(icon: Icon(Icons.analytics_outlined), activeIcon: Icon(Icons.analytics), label: 'Analytics'),
        ],
      ),
    );
  }
}

class _NotificationsPlaceholderScreen extends StatelessWidget {
  const _NotificationsPlaceholderScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none, size: 64, color: AppColors.textHint),
            SizedBox(height: 16),
            Text('No notifications yet', style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
