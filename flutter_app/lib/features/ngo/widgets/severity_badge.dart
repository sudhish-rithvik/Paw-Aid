// lib/features/ngo/widgets/severity_badge.dart
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// Colored severity chip — Critical / High / Medium / Low.
class SeverityBadge extends StatelessWidget {
  final String severity;
  final bool large;

  const SeverityBadge({super.key, required this.severity, this.large = false});

  @override
  Widget build(BuildContext context) {
    final color = _color(severity);
    final label = severity.toUpperCase();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? 12 : 8,
        vertical: large ? 6 : 3,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(large ? 8 : 6),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: large ? 8 : 6,
            height: large ? 8 : 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: large ? 6 : 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: large ? 12 : 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Color _color(String s) => switch (s.toLowerCase()) {
        'critical' => AppColors.critical,
        'high' => AppColors.high,
        'medium' => AppColors.medium,
        'low' => AppColors.low,
        _ => AppColors.textHint,
      };
}
