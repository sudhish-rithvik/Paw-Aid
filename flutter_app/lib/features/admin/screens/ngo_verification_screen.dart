// lib/features/admin/screens/ngo_verification_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../providers/admin_provider.dart';

class NGOVerificationScreen extends ConsumerWidget {
  const NGOVerificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingNGOsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('NGO Verification Queue'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(pendingNGOsProvider.notifier).refresh(),
        child: pendingAsync.when(
          data: (ngos) {
            if (ngos.isEmpty) {
              return ListView(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 120, horizontal: 24),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.verified_outlined, size: 48, color: AppColors.secondary),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'No pending verifications',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'All submitted NGO credentials have been verified.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(24),
              itemCount: ngos.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (ctx, index) {
                final ngo = ngos[index] as Map<String, dynamic>;
                final ngoId = ngo['id'] as String;
                final name = ngo['name'] as String? ?? 'NGO';
                final regNum = ngo['registration_number'] as String? ?? 'N/A';
                final city = ngo['city'] as String? ?? 'Unknown';
                final state = ngo['state'] as String? ?? '';
                final List<dynamic> specs = ngo['specializations'] ?? [];

                return InkWell(
                  onTap: () => context.push('/admin/verification/$ngoId'),
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
                              Expanded(
                                child: Text(
                                  name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.warning.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'PENDING',
                                  style: TextStyle(color: AppColors.warning, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Reg No: $regNum',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textHint),
                              const SizedBox(width: 6),
                              Text('$city, $state', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                            ],
                          ),
                          if (specs.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 6,
                              children: specs.map((spec) => Chip(
                                label: Text(spec.toString()),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                labelStyle: const TextStyle(fontSize: 10),
                              )).toList(),
                            ),
                          ],
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 12),
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text('REVIEW APPLICATION', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                              SizedBox(width: 4),
                              Icon(Icons.arrow_forward_ios, size: 10, color: AppColors.primary),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ).animate().slideY(begin: 0.1, duration: (300 + index * 100).ms);
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => ListView(
            children: [
              Container(
                padding: const EdgeInsets.all(40),
                child: Text('Error loading queue: $err', style: const TextStyle(color: AppColors.critical)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
