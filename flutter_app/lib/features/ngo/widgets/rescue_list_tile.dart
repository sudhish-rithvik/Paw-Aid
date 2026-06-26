// lib/features/ngo/widgets/rescue_list_tile.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../core/theme/app_theme.dart';
import 'severity_badge.dart';
import 'eta_chip.dart';

class RescueListTile extends StatelessWidget {
  final Map<String, dynamic> caseData;
  final bool isAssigned;
  final VoidCallback? onAccept;

  const RescueListTile({
    super.key,
    required this.caseData,
    this.isAssigned = false,
    this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    final caseId = caseData['id'] as String;
    final animal =
        (caseData['ai_analysis'] as Map?)?['animal'] as String? ??
            caseData['animal'] as String? ??
            'Animal';
    final priority = caseData['priority_level'] as String? ?? 'medium';
    final address = caseData['address'] as String? ?? 'Unknown location';
    final status = caseData['status'] as String? ?? 'pending';
    final score = caseData['ai_score'] as num?;

    final createdAt = caseData['created_at'] != null
        ? DateTime.tryParse(caseData['created_at'] as String)
        : null;

    final etaSec = caseData['eta_seconds'] as int?;
    final distM = (caseData['distance_metres'] as num?)?.toDouble();

    return InkWell(
      onTap: () => context.push(
          isAssigned ? '/ngo/active/$caseId' : '/ngo/case/$caseId'),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isAssigned
                ? AppColors.secondary.withOpacity(0.3)
                : AppColors.cardBorder,
            width: isAssigned ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row
            Row(
              children: [
                SeverityBadge(severity: priority),
                const SizedBox(width: 8),
                Text(
                  animal,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: Colors.white),
                ),
                const Spacer(),
                if (score != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Score: ${score.toStringAsFixed(0)}',
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Address
            Row(
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 13, color: AppColors.textHint),
                const SizedBox(width: 4),
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

            // Bottom row
            Row(
              children: [
                EtaChip(
                    durationSeconds: etaSec, distanceMetres: distM),
                const SizedBox(width: 8),
                if (createdAt != null)
                  Text(
                    timeago.format(createdAt),
                    style: const TextStyle(
                        color: AppColors.textHint, fontSize: 10),
                  ),
                const Spacer(),
                if (isAssigned)
                  const Text('ACTIVE',
                      style: TextStyle(
                          color: AppColors.secondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w800))
                else if (onAccept != null && status == 'pending')
                  GestureDetector(
                    onTap: onAccept,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('ACCEPT',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ),
                  )
                else
                  const Icon(Icons.arrow_forward_ios,
                      size: 12, color: AppColors.textHint),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
