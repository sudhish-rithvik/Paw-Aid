// lib/features/ngo/screens/nearby_rescues_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/services/location_service.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/ngo_provider.dart';

class NearbyRescuesScreen extends ConsumerStatefulWidget {
  const NearbyRescuesScreen({super.key});

  @override
  ConsumerState<NearbyRescuesScreen> createState() => _NearbyRescuesScreenState();
}

class _NearbyRescuesScreenState extends ConsumerState<NearbyRescuesScreen> {
  LatLng? _deviceLocation;
  bool _isLocating = true;
  double _radius = 25.0;
  bool _isMapView = false;
  String _severityFilter = 'all';

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    setState(() {
      _isLocating = true;
    });
    final loc = await LocationService.getCurrentLocation();
    if (mounted) {
      setState(() {
        _deviceLocation = loc;
        _isLocating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLocating) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Acquiring GPS location...', style: TextStyle(color: AppColors.textSecondary)),
            ],
          ),
        ),
      );
    }

    if (_deviceLocation == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Nearby Cases')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.gps_off_outlined, size: 48, color: AppColors.critical),
                const SizedBox(height: 16),
                const Text('Location Access Denied', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 8),
                const Text('Nearby rescue queries require device GPS location.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 24),
                ElevatedButton(onPressed: _initLocation, child: const Text('ENABLE LOCATION')),
              ],
            ),
          ),
        ),
      );
    }

    final casesAsync = ref.watch(nearbyCasesProvider(
      lat: _deviceLocation!.latitude,
      lng: _deviceLocation!.longitude,
      radius: _radius,
    ));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Incidents'),
        actions: [
          IconButton(
            icon: Icon(_isMapView ? Icons.list : Icons.map_outlined),
            tooltip: _isMapView ? 'View List' : 'View Map',
            onPressed: () => setState(() => _isMapView = !_isMapView),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Panel
          Container(
            padding: const EdgeInsets.all(16),
            color: AppColors.surface,
            child: Column(
              children: [
                // Radius dropdown
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Search Radius:', style: TextStyle(fontWeight: FontWeight.w600)),
                    DropdownButton<double>(
                      value: _radius,
                      dropdownColor: AppColors.surface,
                      items: [5.0, 10.0, 25.0, 50.0]
                          .map((r) => DropdownMenuItem(value: r, child: Text('${r.toInt()} km')))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _radius = val;
                          });
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Priority chips
                Row(
                  children: [
                    const Text('Priority:', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildChoiceChip('all', 'ALL'),
                            const SizedBox(width: 8),
                            _buildChoiceChip('critical', 'CRITICAL'),
                            const SizedBox(width: 8),
                            _buildChoiceChip('high', 'HIGH'),
                            const SizedBox(width: 8),
                            _buildChoiceChip('medium', 'MEDIUM'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.read(nearbyCasesProvider(
                lat: _deviceLocation!.latitude,
                lng: _deviceLocation!.longitude,
                radius: _radius,
              ).notifier).refresh(
                    lat: _deviceLocation!.latitude,
                    lng: _deviceLocation!.longitude,
                    radius: _radius,
                  ),
              child: casesAsync.when(
                data: (cases) {
                  // Filter client-side
                  final filtered = cases.where((c) {
                    if (_severityFilter == 'all') return true;
                    return (c['priority_level'] as String? ?? 'medium') == _severityFilter;
                  }).toList();

                  if (filtered.isEmpty) {
                    return ListView(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 24),
                          alignment: Alignment.center,
                          child: const Column(
                            children: [
                              Icon(Icons.location_off_outlined, size: 64, color: AppColors.textHint),
                              SizedBox(height: 16),
                              Text('No nearby incidents found', style: TextStyle(fontWeight: FontWeight.bold)),
                              SizedBox(height: 8),
                              Text('Try increasing your search radius or changing your filters.', style: TextStyle(color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                      ],
                    );
                  }

                  return _isMapView
                      ? _buildMap(filtered)
                      : ListView.separated(
                          padding: const EdgeInsets.all(24),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 16),
                          itemBuilder: (ctx, index) {
                            final item = filtered[index] as Map<String, dynamic>;
                            return _buildIncidentCard(context, item);
                          },
                        );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => ListView(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(40),
                      child: Text('Error loading cases: $err', style: const TextStyle(color: AppColors.critical)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChoiceChip(String value, String label) {
    final isSelected = _severityFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _severityFilter = value;
          });
        }
      },
    );
  }

  Widget _buildIncidentCard(BuildContext context, Map<String, dynamic> item) {
    final caseId = item['id'] as String;
    final priority = item['priority_level'] as String? ?? 'medium';
    final address = item['address'] as String? ?? 'Unknown location';
    final distance = item['distance_km'] as double? ?? 0.0;
    
    // AI details
    final animal = item['animal'] as String? ?? 'Animal';

    final priorityColor = switch (priority) {
      'critical' => AppColors.critical,
      'high' => AppColors.high,
      'medium' => AppColors.medium,
      'low' => AppColors.low,
      _ => AppColors.textHint,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: priorityColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: priorityColor.withOpacity(0.3)),
                      ),
                      child: Text(
                        priority.toUpperCase(),
                        style: TextStyle(color: priorityColor, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      animal.toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
                Text(
                  '${distance.toStringAsFixed(1)} km away',
                  style: const TextStyle(color: AppColors.secondary, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.push('/ngo/case/$caseId'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.surfaceVariant,
                foregroundColor: Colors.white,
              ),
              child: const Text('VIEW INCIDENT DETAILS'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMap(List<dynamic> list) {
    final markers = list.map((c) {
      final lat = c['lat'] as double;
      final lng = c['lng'] as double;
      final priority = c['priority_level'] as String? ?? 'medium';
      
      final priorityColor = switch (priority) {
        'critical' => AppColors.critical,
        'high' => AppColors.high,
        'medium' => AppColors.medium,
        'low' => AppColors.low,
        _ => AppColors.textHint,
      };

      return Marker(
        point: LatLng(lat, lng),
        width: 40,
        height: 40,
        child: GestureDetector(
          onTap: () {
            _showQuickView(context, c);
          },
          child: Icon(Icons.location_on, color: priorityColor, size: 30),
        ),
      );
    }).toList();

    // Add device marker
    markers.add(
      Marker(
        point: _deviceLocation!,
        width: 40,
        height: 40,
        child: const Icon(Icons.my_location, color: AppColors.info, size: 24),
      ),
    );

    return FlutterMap(
      options: MapOptions(
        initialCenter: _deviceLocation!,
        initialZoom: 13.0,
      ),
      children: [
        TileLayer(
          urlTemplate: ApiConstants.osmTileUrl,
          userAgentPackageName: 'org.pawaid.app',
        ),
        MarkerLayer(markers: markers),
      ],
    );
  }

  void _showQuickView(BuildContext context, Map<String, dynamic> c) {
    final priority = c['priority_level'] as String? ?? 'medium';
    final address = c['address'] as String? ?? 'Unknown location';
    final distance = c['distance_km'] as double? ?? 0.0;
    final caseId = c['id'] as String;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'CASE DETAILS',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textSecondary),
                ),
                Text(
                  '${distance.toStringAsFixed(1)} KM AWAY',
                  style: const TextStyle(color: AppColors.secondary, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Priority: ${priority.toUpperCase()}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Text(
              address,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                context.push('/ngo/case/$caseId');
              },
              child: const Text('VIEW FULL DETAILS'),
            ),
          ],
        ),
      ),
    );
  }
}
