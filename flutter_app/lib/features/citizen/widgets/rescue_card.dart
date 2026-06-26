// lib/features/citizen/widgets/rescue_card.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../core/theme/app_theme.dart';

class RescueCard extends StatelessWidget {
  final Map<String, dynamic> report;
  final VoidCallback? onTap;

  const RescueCard({super.key, required this.report, this.onTap});

  @override
  Widget build(BuildContext context) {
    final caseId = report['id'] as String;
    final status = report['status'] as String? ?? 'pending';
    final priority = report['priority_level'] as String? ?? 'medium';
    final address = report['address'] as String? ?? 'Unknown location';
    final animal = report['animal'] as String? ?? 'Animal';

    final createdAt = report['created_at'] != null
        ? DateTime.tryParse(report['created_at'] as String)
        : null;

    final statusColor = _statusColor(status);
    final priorityColor = _priorityColor(priority);
    final statusIcon = _statusIcon(status);

    return InkWell(
      onTap: onTap ?? () => context.push('/track/$caseId'),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                // Priority badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: priorityColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border:
                        Border.all(color: priorityColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    priority.toUpperCase(),
                    style: TextStyle(
                      color: priorityColor,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  animal,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Colors.white),
                ),
                const Spacer(),
                // Status chip
                Row(
                  children: [
                    Icon(statusIcon, size: 12, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      status.replaceAll('_', ' ').toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Address
            Row(
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 14, color: AppColors.textHint),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Footer
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  createdAt != null
                      ? timeago.format(createdAt)
                      : '',
                  style: const TextStyle(
                      color: AppColors.textHint, fontSize: 11),
                ),
                const Row(
                  children: [
                    Text('Track Rescue',
                        style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios,
                        size: 9, color: AppColors.primary),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String s) => switch (s) {
        'pending' => AppColors.warning,
        'accepted' => AppColors.info,
        'dispatched' => AppColors.info,
        'animal_picked' => AppColors.primary,
        'vet_treatment' => AppColors.primary,
        'recovery' => AppColors.secondary,
        'completed' => AppColors.success,
        _ => AppColors.textHint,
      };

  Color _priorityColor(String p) => switch (p) {
        'critical' => AppColors.critical,
        'high' => AppColors.high,
        'medium' => AppColors.medium,
        'low' => AppColors.low,
        _ => AppColors.textHint,
      };

  IconData _statusIcon(String s) => switch (s) {
        'pending' => Icons.hourglass_empty,
        'accepted' => Icons.check_circle_outline,
        'dispatched' => Icons.directions_car_outlined,
        'animal_picked' => Icons.pets,
        'vet_treatment' => Icons.local_hospital_outlined,
        'recovery' => Icons.healing_outlined,
        'completed' => Icons.favorite,
        _ => Icons.help_outline,
      };
}
