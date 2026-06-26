// lib/features/ngo/screens/active_rescue_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/ngo_provider.dart';

class ActiveRescueScreen extends ConsumerStatefulWidget {
  final String caseId;
  const ActiveRescueScreen({super.key, required this.caseId});

  @override
  ConsumerState<ActiveRescueScreen> createState() => _ActiveRescueScreenState();
}

class _ActiveRescueScreenState extends ConsumerState<ActiveRescueScreen> {
  Map<String, dynamic>? _caseDetail;
  bool _isLoadingCase = true;
  String? _errorMessage;
  List<LatLng> _routePoints = [];
  bool _isUpdating = false;

  // Image upload per stage
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _fetchCaseDetails();
  }

  Future<void> _fetchCaseDetails() async {
    setState(() {
      _isLoadingCase = true;
      _errorMessage = null;
    });

    try {
      final detail = await ApiService.getCaseDetail(widget.caseId);
      _caseDetail = detail;
      _isLoadingCase = false;

      // Attempt OSRM route fetch
      final ngo = await ref.read(currentNGOProvider.future);
      if (ngo != null && ngo['lat'] != null && ngo['lng'] != null) {
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
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoadingCase = false;
        });
      }
    }
  }

  Future<void> _advanceStage(CaseStatus nextStatus) async {
    // Show a bottom sheet modal to optionally pick a photo and add notes
    XFile? stagePhoto;
    final notesController = TextEditingController();

    final submit = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Advance to ${nextStatus.displayName}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                'Upload a photo or add notes to notify the reporter.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 20),

              // Photo Picker
              if (stagePhoto != null)
                Stack(
                  alignment: Alignment.topRight,
                  children: [
                    Container(
                      height: 150,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          image: FileImage(File(stagePhoto!.path)),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => setModalState(() => stagePhoto = null),
                    ),
                  ],
                )
              else
                OutlinedButton.icon(
                  onPressed: () async {
                    final photo = await _picker.pickImage(
                      source: ImageSource.camera,
                      imageQuality: 80,
                      maxWidth: 800,
                    );
                    if (photo != null) {
                      setModalState(() => stagePhoto = photo);
                    }
                  },
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: const Text('TAKE PROGRESS PHOTO (OPTIONAL)'),
                ),
              const SizedBox(height: 16),

              // Notes
              TextField(
                controller: notesController,
                decoration: const InputDecoration(
                  labelText: 'Progress Notes',
                  hintText: 'e.g. Traffic is heavy, on our way...',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('SUBMIT STATUS UPDATE'),
              ),
            ],
          ),
        ),
      ),
    );

    if (submit == true) {
      setState(() {
        _isUpdating = true;
      });

      try {
        List<int>? bytes;
        if (stagePhoto != null) {
          bytes = await stagePhoto!.readAsBytes();
        }

        await ref.read(rescueQueueProvider.notifier).updateCaseStatus(
              widget.caseId,
              nextStatus.name,
              imageBytes: bytes,
              notes: notesController.text.trim().isNotEmpty ? notesController.text.trim() : null,
            );

        await _fetchCaseDetails();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update stage: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isUpdating = false;
          });
        }
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
        appBar: AppBar(title: const Text('Active Mission')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: AppColors.critical),
                const SizedBox(height: 16),
                Text('Error: ${_errorMessage ?? "Mission details unavailable."}', textAlign: TextAlign.center),
                const SizedBox(height: 24),
                ElevatedButton(onPressed: _fetchCaseDetails, child: const Text('RETRY')),
              ],
            ),
          ),
        ),
      );
    }

    final detail = _caseDetail!;
    final lat = detail['lat'] as double;
    final lng = detail['lng'] as double;
    final address = detail['address'] as String? ?? 'Unknown location';
    final notes = detail['notes'] as String? ?? '';
    final statusStr = detail['status'] as String? ?? 'accepted';
    final currentStatus = CaseStatus.fromString(statusStr);
    
    // AI details
    final aiAnalysis = detail['ai_analysis'] as Map?;
    final animal = aiAnalysis?['animal'] as String? ?? 'Animal';

    // Figure out the next stage
    final stages = CaseStatus.values;
    final currentIndex = stages.indexOf(currentStatus);
    final CaseStatus? nextStatus = currentIndex < stages.length - 1 ? stages[currentIndex + 1] : null;

    return Scaffold(
      appBar: AppBar(
        title: Text('Mission: ${animal.toUpperCase()}'),
      ),
      body: _isUpdating
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Updating status stage...', style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            )
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Live Navigation Route
                  SizedBox(
                    height: 240,
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: LatLng(lat, lng),
                        initialZoom: 14.0,
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
                              child: const Icon(Icons.location_on, color: AppColors.critical, size: 32),
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
                  ),

                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Citizen Call Card
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.person, color: AppColors.primary),
                                ),
                                const SizedBox(width: 16),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Incident Reporter', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                      SizedBox(height: 2),
                                      Text('Click to contact citizen for rescue details.', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.phone, color: AppColors.secondary),
                                  onPressed: () async {
                                    // Try calling a mock or reporter phone
                                    final Uri launchUri = Uri(scheme: 'tel', path: '9876543210');
                                    if (await canLaunchUrl(launchUri)) {
                                      await launchUrl(launchUri);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Advance Stage CTA
                        if (nextStatus != null && nextStatus != CaseStatus.closed)
                          ElevatedButton.icon(
                            onPressed: () => _advanceStage(nextStatus),
                            icon: const Icon(Icons.check_circle_outline),
                            label: Text('MARK AS ${nextStatus.displayName.toUpperCase()}'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.secondary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.secondary.withOpacity(0.3)),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check, color: AppColors.secondary),
                                SizedBox(width: 8),
                                Text(
                                  'MISSION COMPLETED SUCCESSFULLY',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondary),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 32),

                        // vertical 7-stage status timeline
                        Text(
                          'Rescue Stage Timeline',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        _buildTimeline(currentStatus),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildTimeline(CaseStatus currentStatus) {
    final stages = CaseStatus.values;
    final currentIndex = stages.indexOf(currentStatus);

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: stages.length,
      itemBuilder: (context, index) {
        final stage = stages[index];
        final isCompleted = index < currentIndex;
        final isCurrent = index == currentIndex;
        final color = isCompleted
            ? AppColors.secondary
            : isCurrent
                ? AppColors.primary
                : AppColors.textHint;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: isCurrent ? color : Colors.transparent,
                    border: Border.all(color: color, width: 2),
                    shape: BoxShape.circle,
                  ),
                  child: isCompleted
                      ? const Center(child: Icon(Icons.check, size: 12, color: AppColors.secondary))
                      : null,
                ),
                if (index < stages.length - 1)
                  Container(
                    width: 2,
                    height: 40,
                    color: isCompleted ? AppColors.secondary : AppColors.divider,
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${stage.emoji} ${stage.displayName}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      color: isCurrent ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
