// lib/features/admin/widgets/approval_card.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../core/theme/app_theme.dart';

/// Admin NGO verification queue card.
class ApprovalCard extends StatelessWidget {
  final Map<String, dynamic> ngo;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  const ApprovalCard({
    super.key,
    required this.ngo,
    this.onApprove,
    this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final id = ngo['id'] as String;
    final name = ngo['name'] as String? ?? 'Unknown NGO';
    final email = ngo['email'] as String? ?? '';
    final city = ngo['city'] as String? ?? '';
    final state = ngo['state'] as String? ?? '';
    final status = ngo['status'] as String? ?? 'pending';
    final specs = List<String>.from(ngo['specializations'] as List? ?? []);
    final createdAt = ngo['created_at'] != null
        ? DateTime.tryParse(ngo['created_at'] as String)
        : null;

    final statusColor = switch (status) {
      'pending' => AppColors.warning,
      'approved' => AppColors.success,
      'rejected' => AppColors.critical,
      'suspended' => AppColors.textHint,
      _ => AppColors.textHint,
    };

    return InkWell(
      onTap: () => context.push('/admin/verification/$id'),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: status == 'pending'
                ? AppColors.warning.withOpacity(0.3)
                : AppColors.cardBorder,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: statusColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                        color: statusColor,
                        fontSize: 9,
                        fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Location + email
            Text(
              [city, state].where((s) => s.isNotEmpty).join(', '),
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12),
            ),
            if (email.isNotEmpty)
              Text(email,
                  style: const TextStyle(
                      color: AppColors.textHint, fontSize: 11)),

            if (specs.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: specs
                    .take(4)
                    .map((s) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(s,
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 10)),
                        ))
                    .toList(),
              ),
            ],

            const SizedBox(height: 12),

            Row(
              children: [
                if (createdAt != null)
                  Text(
                    'Applied ${timeago.format(createdAt)}',
                    style: const TextStyle(
                        color: AppColors.textHint, fontSize: 10),
                  ),
                const Spacer(),
                // Quick action buttons (only for pending)
                if (status == 'pending') ...[
                  if (onReject != null)
                    TextButton(
                      onPressed: onReject,
                      style: TextButton.styleFrom(
                          foregroundColor: AppColors.critical,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize:
                              MaterialTapTargetSize.shrinkWrap),
                      child: const Text('REJECT',
                          style: TextStyle(fontSize: 11)),
                    ),
                  if (onApprove != null)
                    ElevatedButton(
                      onPressed: onApprove,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize:
                              MaterialTapTargetSize.shrinkWrap),
                      child: const Text('APPROVE',
                          style: TextStyle(fontSize: 11)),
                    ),
                ] else
                  const Row(
                    children: [
                      Text('View Details',
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
}
