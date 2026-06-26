// lib/features/admin/widgets/city_heatmap.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_heatmap/flutter_map_heatmap.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_theme.dart';

/// Admin city heatmap using flutter_map + flutter_map_heatmap.
/// [hotspots] is a list of maps with 'lat', 'lng', and optional 'weight'.
class CityHeatmap extends StatelessWidget {
  final List<Map<String, dynamic>> hotspots;
  final LatLng? initialCenter;
  final double initialZoom;

  const CityHeatmap({
    super.key,
    required this.hotspots,
    this.initialCenter,
    this.initialZoom = 11,
  });

  @override
  Widget build(BuildContext context) {
    final center = initialCenter ?? const LatLng(13.0827, 80.2707);

    if (hotspots.isEmpty) {
      return Container(
        color: AppColors.surface,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.map_outlined, size: 48, color: AppColors.textHint),
              SizedBox(height: 12),
              Text('No incident data yet',
                  style: TextStyle(color: AppColors.textSecondary)),
            ],
          ),
        ),
      );
    }

    final heatData = hotspots
        .map((h) => WeightedLatLng(
              LatLng(
                (h['lat'] as num).toDouble(),
                (h['lng'] as num).toDouble(),
              ),
              (h['weight'] as num?)?.toDouble() ?? 1.0,
            ))
        .toList();

    return FlutterMap(
      options: MapOptions(
        initialCenter: center,
        initialZoom: initialZoom,
      ),
      children: [
        TileLayer(
          urlTemplate: ApiConstants.osmTileUrl,
          userAgentPackageName: 'org.pawaid.app',
        ),
        HeatMapLayer(
          heatMapDataSource: InMemoryHeatMapDataSource(data: heatData),
          heatMapOptions: HeatMapOptions(
            gradient: HeatMapOptions.defaultGradient,
            minOpacity: 0.3,
            radius: 60,
          ),
        ),
      ],
    );
  }
}
