// lib/features/citizen/widgets/status_timeline.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_theme.dart';

class StatusTimeline extends StatelessWidget {
  final CaseStatus currentStatus;

  const StatusTimeline({super.key, required this.currentStatus});

  @override
  Widget build(BuildContext context) {
    final stages = CaseStatus.values;
    final currentIndex = stages.indexOf(currentStatus);

    return Column(
      children: List.generate(stages.length, (index) {
        final stage = stages[index];
        final isCompleted = index < currentIndex;
        final isCurrent = index == currentIndex;
        final isPending = index > currentIndex;

        final nodeColor = isCompleted
            ? AppColors.secondary
            : isCurrent
                ? AppColors.primary
                : AppColors.surfaceVariant;

        final lineColor =
            isCompleted ? AppColors.secondary : AppColors.divider;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timeline node + connector
            SizedBox(
              width: 32,
              child: Column(
                children: [
                  // Node
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: nodeColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isCurrent
                            ? AppColors.primary
                            : isCompleted
                                ? AppColors.secondary
                                : AppColors.border,
                        width: 2,
                      ),
                      boxShadow: isCurrent
                          ? [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.4),
                                blurRadius: 8,
                                spreadRadius: 2,
                              )
                            ]
                          : null,
                    ),
                    child: Center(
                      child: isCompleted
                          ? const Icon(Icons.check,
                              size: 14, color: Colors.black)
                          : isCurrent
                              ? Text(stage.emoji,
                                  style: const TextStyle(fontSize: 12))
                              : Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isPending
                                        ? AppColors.textHint
                                        : Colors.white,
                                  ),
                                ),
                    ),
                  ),
                  // Connector line
                  if (index < stages.length - 1)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      width: 2,
                      height: 44,
                      color: lineColor,
                    ),
                ],
              ),
            ),

            const SizedBox(width: 16),

            // Stage info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      stage.displayName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            isCurrent ? FontWeight.w700 : FontWeight.w500,
                        color: isCurrent
                            ? Colors.white
                            : isCompleted
                                ? AppColors.textSecondary
                                : AppColors.textHint,
                      ),
                    ),
                    if (isCurrent) ...[
                      const SizedBox(height: 4),
                      Text(
                        _getStageDescription(stage),
                        style: const TextStyle(
                          color: AppColors.textHint,
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 3,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          gradient: const LinearGradient(
                            colors: [AppColors.primary, AppColors.secondary],
                          ),
                        ),
                      )
                          .animate(onPlay: (c) => c.repeat(reverse: true))
                          .shimmer(duration: 1500.ms, color: Colors.white24),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  String _getStageDescription(CaseStatus status) => switch (status) {
        CaseStatus.pending =>
          'Report received. AI is scoring priority and dispatching alerts.',
        CaseStatus.accepted =>
          'An NGO rescue team has accepted and is preparing logistics.',
        CaseStatus.dispatched =>
          'Rescue vehicle is en route to the animal\'s location.',
        CaseStatus.animalPicked =>
          'Animal picked up and en route to the clinic.',
        CaseStatus.vetTreatment =>
          'Veterinary team performing emergency treatment.',
        CaseStatus.recovery =>
          'Animal is stable and recovering at the shelter.',
        CaseStatus.completed =>
          'Rescue completed successfully! The animal is safe. ❤️',
        CaseStatus.closed => 'This case is resolved and closed.',
      };
}
