// lib/core/widgets/role_switcher.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';
import '../../features/auth/providers/auth_provider.dart';

class RoleSwitcherButton extends ConsumerWidget {
  const RoleSwitcherButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);
    final role = profileAsync.valueOrNull?['role'] as String? ?? 'citizen';

    final (roleLabel, roleIcon, badgeColor) = switch (role) {
      'admin' => ('Admin', Icons.admin_panel_settings, AppColors.info),
      'ngo_staff' => ('NGO Staff', Icons.home_work, AppColors.secondary),
      _ => ('Citizen', Icons.person, AppColors.primary),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: ActionChip(
        avatar: Icon(roleIcon, size: 16, color: Colors.white),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              roleLabel,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, size: 16, color: Colors.white70),
          ],
        ),
        backgroundColor: badgeColor.withOpacity(0.85),
        side: BorderSide(color: badgeColor, width: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
        onPressed: () => _showAccountSwitcher(context, ref, role),
      ),
    );
  }

  void _showAccountSwitcher(BuildContext context, WidgetRef ref, String currentRole) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textHint.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Row(
                  children: [
                    Icon(Icons.swap_horiz, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text(
                      'Switch User Account',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Instantly switch between roles to test the full rescue lifecycle.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),

                // 1. Citizen
                _buildAccountTile(
                  context: ctx,
                  ref: ref,
                  targetRole: 'citizen',
                  name: 'Priya Ramesh',
                  email: 'citizen@pawaid.com',
                  description: 'Citizen • Report injured animals & track rescues',
                  icon: Icons.person,
                  color: AppColors.primary,
                  isSelected: currentRole == 'citizen',
                  route: '/citizen/home',
                ),
                const SizedBox(height: 10),

                // 2. NGO Staff
                _buildAccountTile(
                  context: ctx,
                  ref: ref,
                  targetRole: 'ngo_staff',
                  name: 'CARF Rescue Team',
                  email: 'ngo@pawaid.com',
                  description: 'NGO Dispatcher • Live queue, accept cases & update stages',
                  icon: Icons.home_work,
                  color: AppColors.secondary,
                  isSelected: currentRole == 'ngo_staff',
                  route: '/ngo/dashboard',
                ),
                const SizedBox(height: 10),

                // 3. Admin
                _buildAccountTile(
                  context: ctx,
                  ref: ref,
                  targetRole: 'admin',
                  name: 'System Admin',
                  email: 'admin@pawaid.com',
                  description: 'City Admin • Approve NGOs, live heatmaps & city analytics',
                  icon: Icons.admin_panel_settings,
                  color: AppColors.info,
                  isSelected: currentRole == 'admin',
                  route: '/admin/dashboard',
                ),
                const SizedBox(height: 16),

                // Sign Out Option
                OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await ref.read(authNotifierProvider.notifier).signOut();
                    if (context.mounted) {
                      context.go('/login');
                    }
                  },
                  icon: const Icon(Icons.logout, color: AppColors.critical, size: 18),
                  label: const Text('SIGN OUT', style: TextStyle(color: AppColors.critical)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.critical),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAccountTile({
    required BuildContext context,
    required WidgetRef ref,
    required String targetRole,
    required String name,
    required String email,
    required String description,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required String route,
  }) {
    return InkWell(
      onTap: () async {
        Navigator.pop(context);
        if (!isSelected) {
          await ref.read(authNotifierProvider.notifier).signInWithRole(targetRole);
          if (context.mounted) {
            context.go(route);
          }
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.12) : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : AppColors.divider,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'ACTIVE',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.black),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    email,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: const TextStyle(fontSize: 10, color: AppColors.textHint),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }
}
