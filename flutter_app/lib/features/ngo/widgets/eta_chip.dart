// lib/features/ngo/widgets/eta_chip.dart
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// Displays an estimated travel time chip from OSRM.
class EtaChip extends StatelessWidget {
  /// Duration in seconds. Pass null while loading.
  final int? durationSeconds;
  /// Distance in metres.
  final double? distanceMetres;
  final bool isLoading;

  const EtaChip({
    super.key,
    this.durationSeconds,
    this.distanceMetres,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return _buildChip(Icons.timer_outlined, 'Calculating...', AppColors.textHint);
    }

    if (durationSeconds == null) {
      return _buildChip(Icons.timer_off_outlined, 'ETA unavailable', AppColors.textHint);
    }

    final minutes = (durationSeconds! / 60).ceil();
    final km = distanceMetres != null
        ? (distanceMetres! / 1000).toStringAsFixed(1)
        : null;

    final label = km != null ? '$minutes min · $km km' : '$minutes min';
    final color = minutes <= 10
        ? AppColors.success
        : minutes <= 25
            ? AppColors.medium
            : AppColors.critical;

    return _buildChip(Icons.directions_car_outlined, label, color);
  }

  Widget _buildChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
