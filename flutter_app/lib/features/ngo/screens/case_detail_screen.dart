// lib/features/ngo/screens/case_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/ngo_provider.dart';

class CaseDetailScreen extends ConsumerStatefulWidget {
  final String caseId;
  const CaseDetailScreen({super.key, required this.caseId});

  @override
  ConsumerState<CaseDetailScreen> createState() => _CaseDetailScreenState();
}

class _CaseDetailScreenState extends ConsumerState<CaseDetailScreen> {
  bool _isLoadingRoute = false;
  List<LatLng> _routePoints = [];
  Map<String, dynamic>? _caseDetail;
  bool _isLoadingCase = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchCaseAndRoute();
  }

  Future<void> _fetchCaseAndRoute() async {
    setState(() {
      _isLoadingCase = true;
      _errorMessage = null;
    });

    try {
      final detail = await ApiService.getCaseDetail(widget.caseId);
      _caseDetail = detail;
      _isLoadingCase = false;

      // Now attempt OSRM route fetch
      final ngo = await ref.read(currentNGOProvider.future);
      if (ngo != null && ngo['lat'] != null && ngo['lng'] != null) {
        setState(() {
          _isLoadingRoute = true;
        });
        
        final fromLat = ngo['lat'] as double;
        final fromLng = ngo['lng'] as double;
        final toLat = detail['lat'] as double;
        final toLng = detail['lng'] as double;

        final routeData = await ApiService.getRoute(
          fromLat: fromLat,
          fromLng: fromLng,
          toLat: toLat,
          toLng: toLng,
        );

        if (mounted) {
          setState(() {
            _routePoints = routeData.map((c) => LatLng(c[0], c[1])).toList();
            _isLoadingRoute = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingRoute = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoadingCase = false;
          _isLoadingRoute = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingCase) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null || _caseDetail == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Rescue Details')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: AppColors.critical),
                const SizedBox(height: 16),
                Text('Error: ${_errorMessage ?? "Case details not found."}', textAlign: TextAlign.center),
                const SizedBox(height: 24),
                ElevatedButton(onPressed: _fetchCaseAndRoute, child: const Text('RETRY')),
              ],
            ),
          ),
        ),
      );
    }

    final detail = _caseDetail!;
    final caseId = detail['id'] as String;
    final lat = detail['lat'] as double;
    final lng = detail['lng'] as double;
    final address = detail['address'] as String? ?? 'Unknown location';
    final notes = detail['notes'] as String? ?? 'No reporter notes provided.';
    // ignore: unused_local_variable
    final status = detail['status'] as String? ?? 'pending';
    final priority = detail['priority_level'] as String? ?? 'medium';
    final imagePath = detail['image_path'] as String?;
    final assignedNgoId = detail['assigned_ngo_id'] as String?;

    // AI Analysis Block
    final aiAnalysis = detail['ai_analysis'] as Map?;
    final animal = aiAnalysis?['animal'] as String? ?? 'Unknown Species';
    final injuries = List<String>.from(aiAnalysis?['visible_injuries'] ?? []);
    final mobility = aiAnalysis?['mobility'] as String? ?? 'Unknown';
    final pain = aiAnalysis?['pain_level'] as String? ?? 'Unknown';
    final confidence = (aiAnalysis?['confidence'] as num?)?.toDouble() ?? 0.0;
    final recommendedAction = aiAnalysis?['recommended_action'] as String? ?? '';
    final reason = aiAnalysis?['reason'] as String? ?? '';

    final priorityColor = switch (priority) {
      'critical' => AppColors.critical,
      'high' => AppColors.high,
      'medium' => AppColors.medium,
      'low' => AppColors.low,
      _ => AppColors.textHint,
    };

    final isAssignedToUs = assignedNgoId != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rescue Incident Details'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Animal Photo
            if (imagePath != null && imagePath.isNotEmpty)
              Image.network(
                SupabaseService.getPublicUrl(ApiConstants.animalImagesBucket, imagePath),
                height: 240,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 240,
                  color: AppColors.surface,
                  child: const Icon(Icons.broken_image, size: 48, color: AppColors.textHint),
                ),
              )
            else
              Container(
                height: 200,
                color: AppColors.surface,
                child: const Icon(Icons.pets, size: 64, color: AppColors.textHint),
              ),

            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title + Priority Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            animal.toUpperCase(),
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: Colors.white),
                          ),
                          const SizedBox(height: 4),
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
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          children: [
                            const Text('AI Confidence', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                            const SizedBox(height: 2),
                            Text('${confidence.toStringAsFixed(1)}%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.secondary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // AI analysis glassmorphism card
                  _buildSectionHeader('AI Computer Vision Diagnostics'),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (injuries.isNotEmpty) ...[
                            const Text('Visible Injuries:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white70)),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: injuries.map((inj) => Chip(
                                label: Text(inj),
                                backgroundColor: AppColors.surfaceVariant,
                              )).toList(),
                            ),
                            const SizedBox(height: 16),
                          ],
                          Row(
                            children: [
                              Expanded(
                                child: _buildMiniStat('Mobility', mobility, Icons.directions_run),
                              ),
                              Expanded(
                                child: _buildMiniStat('Pain Level', pain, Icons.healing),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 16),
                          const Text('Recommended Action:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white70)),
                          const SizedBox(height: 4),
                          Text(recommendedAction, style: const TextStyle(fontSize: 13, color: Colors.white)),
                          const SizedBox(height: 12),
                          const Text('Diagnosis Rationale:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white70)),
                          const SizedBox(height: 4),
                          Text(reason, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Reporter Details / Notes
                  _buildSectionHeader('Incident Details'),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.location_on_outlined, size: 18, color: AppColors.primary),
                              SizedBox(width: 8),
                              Text('Address', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.only(left: 26.0),
                            child: Text(address, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                          ),
                          const SizedBox(height: 16),
                          const Row(
                            children: [
                              Icon(Icons.description_outlined, size: 18, color: AppColors.primary),
                              SizedBox(width: 8),
                              Text('Citizen Notes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.only(left: 26.0),
                            child: Text(notes, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Route / Location Map
                  _buildSectionHeader('Rescue Route'),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 250,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        children: [
                          FlutterMap(
                            options: MapOptions(
                              initialCenter: LatLng(lat, lng),
                              initialZoom: 13.0,
                            ),
                            children: [
                              TileLayer(
                                urlTemplate: ApiConstants.osmTileUrl,
                                userAgentPackageName: 'org.pawaid.app',
                              ),
                              if (_routePoints.isNotEmpty)
                                PolylineLayer(
                                  polylines: [
                                    Polyline(
                                      points: _routePoints,
                                      color: AppColors.primary,
                                      strokeWidth: 4.0,
                                    ),
                                  ],
                                ),
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: LatLng(lat, lng),
                                    width: 40,
                                    height: 40,
                                    child: const Icon(Icons.location_on, color: AppColors.critical, size: 30),
                                  ),
                                  if (_routePoints.isNotEmpty)
                                    Marker(
                                      point: _routePoints.first,
                                      width: 40,
                                      height: 40,
                                      child: const Icon(Icons.home_work, color: AppColors.secondary, size: 30),
                                    ),
                                ],
                              ),
                            ],
                          ),
                          if (_isLoadingRoute)
                            Container(
                              color: Colors.black.withOpacity(0.3),
                              child: const Center(child: CircularProgressIndicator()),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Bottom Action CTAs
                  if (isAssignedToUs)
                    ElevatedButton(
                      onPressed: () => context.push('/ngo/active/$caseId'),
                      child: const Text('OPEN LIVE MISSION TRACKER'),
                    )
                  else
                    ElevatedButton(
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Accept Rescue'),
                            content: const Text('Do you want to accept this rescue request and dispatch your team?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('CANCEL'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('ACCEPT'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          final router = GoRouter.of(context);
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            await ref.read(rescueQueueProvider.notifier).accept(caseId);
                            if (mounted) {
                              router.push('/ngo/active/$caseId');
                            }
                          } catch (e) {
                            if (mounted) {
                              messenger.showSnackBar(
                                SnackBar(content: Text('Failed to accept case: $e')),
                              );
                            }
                          }
                        }
                      },
                      child: const Text('ACCEPT EMERGENCY RESCUE'),
                    ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white, letterSpacing: 0.5),
    );
  }

  Widget _buildMiniStat(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textHint)),
            Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
      ],
    );
  }
}
