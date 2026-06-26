// lib/features/citizen/screens/track_rescue_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/api_constants.dart';
import '../providers/report_provider.dart';

class TrackRescueScreen extends ConsumerStatefulWidget {
  final String caseId;
  const TrackRescueScreen({super.key, required this.caseId});

  @override
  ConsumerState<TrackRescueScreen> createState() => _TrackRescueScreenState();
}

class _TrackRescueScreenState extends ConsumerState<TrackRescueScreen> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    // Refresh case status every 15 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      ref.read(caseStatusNotifierProvider(widget.caseId).notifier).refresh();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final caseAsync = ref.watch(caseStatusNotifierProvider(widget.caseId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Rescue Track'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(caseStatusNotifierProvider(widget.caseId).notifier).refresh(),
          ),
        ],
      ),
      body: caseAsync.when(
        data: (caseData) {
          final lat = caseData['lat'] as double;
          final lng = caseData['lng'] as double;
          final animalLocation = LatLng(lat, lng);
          final statusStr = caseData['status'] as String? ?? 'pending';
          final status = CaseStatus.fromString(statusStr);
          final priority = caseData['priority_level'] as String? ?? 'medium';
          final address = caseData['address'] as String? ?? 'Acquiring address...';
          final notes = caseData['notes'] as String? ?? '';
          final imagePath = caseData['image_path'] as String?;
          final ngoName = caseData['ngo_name'] as String?;
          final ngoPhone = caseData['ngo_phone'] as String?;

          // AI details
          final animal = caseData['animal'] as String? ?? 'Animal';
          final injuries = List<String>.from(caseData['visible_injuries'] ?? []);
          final severity = caseData['severity'] as String? ?? 'Medium';
          final recommendedAction = caseData['recommended_action'] as String? ?? '';

          final priorityColor = switch (priority) {
            'critical' => AppColors.critical,
            'high' => AppColors.high,
            'medium' => AppColors.medium,
            'low' => AppColors.low,
            _ => AppColors.textHint,
          };

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Map View (Animal Position)
                SizedBox(
                  height: 240,
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: animalLocation,
                      initialZoom: 15.0,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: ApiConstants.osmTileUrl,
                        userAgentPackageName: 'org.pawaid.app',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: animalLocation,
                            width: 60,
                            height: 60,
                            child: const Icon(
                              Icons.location_on,
                              color: AppColors.critical,
                              size: 40,
                            )
                                .animate(onPlay: (controller) => controller.repeat(reverse: true))
                                .scale(end: const Offset(1.2, 1.2), duration: 1000.ms, curve: Curves.easeInOut),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 2. Incident Summary Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${animal.toUpperCase()} RESCUE',
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1),
                              ),
                              const SizedBox(height: 4),
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
                                      style: TextStyle(
                                        color: priorityColor,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'AI Severity: $severity',
                                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Text(
                            status.emoji,
                            style: const TextStyle(fontSize: 32),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Image details
                      if (imagePath != null && imagePath.isNotEmpty) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            SupabaseService.getPublicUrl(ApiConstants.animalImagesBucket, imagePath),
                            height: 160,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              height: 160,
                              color: AppColors.surface,
                              child: const Icon(Icons.broken_image, color: AppColors.textHint),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Address Card
                      _buildInfoCard(
                        icon: Icons.location_on_outlined,
                        title: 'Location Details',
                        content: address,
                      ),
                      const SizedBox(height: 12),

                      // AI Analysis summary
                      if (injuries.isNotEmpty || recommendedAction.isNotEmpty) ...[
                        _buildInfoCard(
                          icon: Icons.psychology_outlined,
                          title: 'AI Diagnostics',
                          content: 'Injuries: ${injuries.join(", ")}\nRecommended Action: $recommendedAction',
                          titleColor: AppColors.secondary,
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Assigned NGO Details
                      if (ngoName != null) ...[
                        _buildInfoCard(
                          icon: Icons.business_outlined,
                          title: 'Assigned NGO',
                          content: '$ngoName\nPhone: ${ngoPhone ?? "Unavailable"}',
                          titleColor: AppColors.primary,
                        ),
                        const SizedBox(height: 24),
                      ] else ...[
                        _buildInfoCard(
                          icon: Icons.hourglass_empty,
                          title: 'Rescue Agency Assignment',
                          content: 'Connecting case with closest specialty NGO team...',
                        ),
                        const SizedBox(height: 24),
                      ],

                      // 3. Rescue Progress Timeline (7 stages)
                      Text(
                        'Rescue Progress',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      _buildTimeline(status),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(40.0),
            child: Text(
              'Failed to retrieve case status. Please check connection.\nError: $err',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.critical),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String content,
    Color titleColor = Colors.white,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: titleColor, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: titleColor),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    content,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
                  ),
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
            // Timeline line and circle
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
            // Timeline description
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
                  const SizedBox(height: 4),
                  if (isCurrent)
                    Text(
                      _getStageDescription(stage),
                      style: const TextStyle(color: AppColors.textHint, fontSize: 11),
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

  String _getStageDescription(CaseStatus status) {
    return switch (status) {
      CaseStatus.pending => 'Report has been received. Our backend AI is scoring priority and dispatching alerts.',
      CaseStatus.accepted => 'An NGO rescue team has accepted the dispatch and is preparing logistics.',
      CaseStatus.dispatched => 'The rescue vehicle is currently en route to the animal\'s location.',
      CaseStatus.animalPicked => 'The animal has been successfully captured and is on the way to the clinic.',
      CaseStatus.vetTreatment => 'The veterinary team is performing emergency diagnostics and treatment.',
      CaseStatus.recovery => 'The animal is stable and recovering under observation at our shelter.',
      CaseStatus.completed => 'The rescue has been completed successfully! The animal is safe.',
      CaseStatus.closed => 'This case is resolved and closed.',
    };
  }
}
