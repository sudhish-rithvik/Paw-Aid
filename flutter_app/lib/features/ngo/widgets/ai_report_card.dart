// lib/features/ngo/widgets/ai_report_card.dart
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import 'severity_badge.dart';

/// Structured card that displays the on-device AI analysis result.
/// Distinguishes AI pending, AI completed, and AI unavailable states.
class AIReportCard extends StatelessWidget {
  final Map<String, dynamic>? analysis;
  final bool isLoading;

  const AIReportCard({
    super.key,
    this.analysis,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return _buildShimmer();
    }

    if (analysis == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardBorderLight, width: 1.2),
        ),
        child: const Row(
          children: [
            Icon(Icons.hourglass_empty, color: AppColors.textHintLight, size: 20),
            SizedBox(width: 12),
            Text('AI analysis pending on-device evaluation...',
                style: TextStyle(color: AppColors.textSecondaryLight)),
          ],
        ),
      );
    }

    final status = (analysis!['status'] ?? analysis!['aiAnalysisStatus'] ?? 'COMPLETED')
        .toString()
        .toUpperCase();

    if (status == 'PENDING') {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardBorderLight, width: 1.2),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.secondary),
            ),
            SizedBox(width: 12),
            Text('On-device LiteRT triage in progress...',
                style: TextStyle(color: AppColors.textSecondaryLight, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    if (status == 'UNAVAILABLE') {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardBorderLight, width: 1.2),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline, color: AppColors.textHintLight, size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'AI Model Unavailable: Local LiteRT/TFLite model weights (.tflite) not bundled in this build.',
                style: TextStyle(color: AppColors.textHintLight, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    final animal = analysis!['animal'] as String? ?? analysis!['animalDetected'] as String? ?? 'Unknown';
    final injuriesRaw = analysis!['visible_injuries'] ?? analysis!['visibleInjuries'] ?? analysis!['injuriesDetected'];
    final injuries = injuriesRaw is List
        ? List<String>.from(injuriesRaw)
        : (injuriesRaw is String && injuriesRaw.isNotEmpty ? [injuriesRaw] : <String>[]);
    final mobility = analysis!['mobility'] as String? ?? analysis!['mobilityAssessment'] as String? ?? 'Unknown';
    final painLevel = analysis!['pain_level'] as String? ?? analysis!['painLevel'] as String? ?? 'Unknown';
    final severity = (analysis!['severity'] as String? ?? analysis!['severityScore'] as String? ?? 'medium').toLowerCase();
    final confidence = (analysis!['confidence'] as num?)?.toDouble() ?? 0;
    final recommendedAction = analysis!['recommended_action'] as String? ?? analysis!['recommendedAction'] as String? ?? '';
    final reason = analysis!['reason'] as String? ?? '';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.secondary.withValues(alpha: 0.15),
                  AppColors.secondary.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                const Icon(Icons.psychology, color: AppColors.secondary, size: 20),
                const SizedBox(width: 10),
                const Text(
                  'On-Device AI Triage',
                  style: TextStyle(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                SeverityBadge(severity: severity),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Animal + confidence
                Row(
                  children: [
                    Text(
                      animal,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${(confidence * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(
                            color: AppColors.secondary,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                        const Text(
                          'confidence',
                          style: TextStyle(color: AppColors.textHintLight, fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 14),
                const Divider(color: AppColors.divider, height: 1),
                const SizedBox(height: 14),

                // Injuries
                if (injuries.isNotEmpty) ...[
                  _buildRow('Visible Injuries', injuries.join(' • '), AppColors.critical),
                  const SizedBox(height: 10),
                ],

                // Mobility + Pain in a row
                Row(
                  children: [
                    Expanded(
                      child: _buildSmallInfo('Mobility', mobility, Icons.directions_walk),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSmallInfo('Pain Level', painLevel, Icons.monitor_heart),
                    ),
                  ],
                ),

                const SizedBox(height: 14),
                const Divider(color: AppColors.divider, height: 1),
                const SizedBox(height: 14),

                // Recommended action
                _buildRow('Recommended Action', recommendedAction, AppColors.primary),

                if (reason.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _buildRow('Reason', reason, AppColors.textSecondary),
                ],
              ],
            ),
          ),

          // Mandatory Veterinary Disclaimer Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant.withValues(alpha: 0.6),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.warning),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Preliminary emergency triage only. Not a veterinary medical diagnosis.',
                    style: TextStyle(
                      color: AppColors.textHintLight,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: AppColors.textHintLight,
            fontSize: 9,
            letterSpacing: 1,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: valueColor, fontSize: 13, height: 1.4)),
      ],
    );
  }

  Widget _buildSmallInfo(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariantLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: AppColors.textHintLight),
              const SizedBox(width: 4),
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  color: AppColors.textHintLight,
                  fontSize: 9,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmer() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorderLight, width: 1.2),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}
