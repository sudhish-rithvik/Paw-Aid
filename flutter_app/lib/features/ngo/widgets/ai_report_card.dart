// lib/features/ngo/widgets/ai_report_card.dart
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import 'severity_badge.dart';

/// Structured card that displays the full AI analysis result.
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
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: const Row(
          children: [
            Icon(Icons.hourglass_empty, color: AppColors.textHint, size: 20),
            SizedBox(width: 12),
            Text('AI analysis in progress...',
                style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    final animal = analysis!['animal'] as String? ?? 'Unknown';
    final injuries =
        List<String>.from(analysis!['visible_injuries'] as List? ?? []);
    final mobility = analysis!['mobility'] as String? ?? 'Unknown';
    final painLevel = analysis!['pain_level'] as String? ?? 'Unknown';
    final severity = analysis!['severity'] as String? ?? 'medium';
    final confidence = (analysis!['confidence'] as num?)?.toDouble() ?? 0;
    final recommendedAction =
        analysis!['recommended_action'] as String? ?? '';
    final reason = analysis!['reason'] as String? ?? '';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.secondary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.secondary.withOpacity(0.15),
                  AppColors.secondary.withOpacity(0.05),
                ],
              ),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                const Icon(Icons.psychology,
                    color: AppColors.secondary, size: 20),
                const SizedBox(width: 10),
                const Text(
                  'AI Veterinary Analysis',
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
                        const Text('confidence',
                            style: TextStyle(
                                color: AppColors.textHint, fontSize: 10)),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 14),
                const Divider(color: AppColors.divider, height: 1),
                const SizedBox(height: 14),

                // Injuries
                if (injuries.isNotEmpty) ...[
                  _buildRow('Visible Injuries',
                      injuries.join(' • '), AppColors.critical),
                  const SizedBox(height: 10),
                ],

                // Mobility + Pain in a row
                Row(
                  children: [
                    Expanded(
                        child: _buildSmallInfo(
                            'Mobility', mobility, Icons.directions_walk)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _buildSmallInfo(
                            'Pain Level', painLevel, Icons.monitor_heart)),
                  ],
                ),

                const SizedBox(height: 14),
                const Divider(color: AppColors.divider, height: 1),
                const SizedBox(height: 14),

                // Recommended action
                _buildRow('Recommended Action', recommendedAction,
                    AppColors.primary),

                if (reason.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _buildRow('Reason', reason, AppColors.textSecondary),
                ],
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
        Text(label.toUpperCase(),
            style: const TextStyle(
                color: AppColors.textHint,
                fontSize: 9,
                letterSpacing: 1,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                color: valueColor, fontSize: 13, height: 1.4)),
      ],
    );
  }

  Widget _buildSmallInfo(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: AppColors.textHint),
              const SizedBox(width: 4),
              Text(label.toUpperCase(),
                  style: const TextStyle(
                      color: AppColors.textHint,
                      fontSize: 9,
                      letterSpacing: 0.5)),
            ],
          ),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildShimmer() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}
