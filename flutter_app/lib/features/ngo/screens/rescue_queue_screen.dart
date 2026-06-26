// lib/features/ngo/screens/rescue_queue_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../providers/ngo_provider.dart';

class RescueQueueScreen extends ConsumerStatefulWidget {
  const RescueQueueScreen({super.key});

  @override
  ConsumerState<RescueQueueScreen> createState() => _RescueQueueScreenState();
}

class _RescueQueueScreenState extends ConsumerState<RescueQueueScreen> {
  String _selectedPriority = 'all';

  @override
  Widget build(BuildContext context) {
    final queueAsync = ref.watch(rescueQueueProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rescue Incident Queue'),
      ),
      body: Column(
        children: [
          // Filter Chips Row
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            color: AppColors.surface,
            child: Row(
              children: [
                _buildFilterChip('all', 'ALL'),
                const SizedBox(width: 8),
                _buildFilterChip('critical', 'CRITICAL'),
                const SizedBox(width: 8),
                _buildFilterChip('high', 'HIGH'),
                const SizedBox(width: 8),
                _buildFilterChip('medium', 'MEDIUM'),
              ],
            ),
          ),
          
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.read(rescueQueueProvider.notifier).refresh(),
              child: queueAsync.when(
                data: (cases) {
                  // Apply client-side priority filters
                  final filteredCases = cases.where((c) {
                    if (_selectedPriority == 'all') return true;
                    final priority = c['priority_level'] as String? ?? 'medium';
                    return priority == _selectedPriority;
                  }).toList();

                  if (filteredCases.isEmpty) {
                    return ListView(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 100, horizontal: 24),
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.playlist_add_check, size: 64, color: AppColors.textHint),
                              const SizedBox(height: 16),
                              const Text(
                                'Queue is empty',
                                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _selectedPriority == 'all'
                                    ? 'No active cases in your area.'
                                    : 'No $_selectedPriority priority cases in the queue.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(24),
                    itemCount: filteredCases.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (ctx, index) {
                      final c = filteredCases[index] as Map<String, dynamic>;
                      return _buildQueueCard(context, c);
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => ListView(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(40),
                      alignment: Alignment.center,
                      child: Text('Error loading queue: $err', style: const TextStyle(color: AppColors.critical)),
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

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedPriority == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedPriority = value;
          });
        }
      },
    );
  }

  Widget _buildQueueCard(BuildContext context, Map<String, dynamic> c) {
    final caseId = c['id'] as String;
    final priority = c['priority_level'] as String? ?? 'medium';
    final address = c['address'] as String? ?? 'Unknown location';
    final aiScore = c['ai_score'] as double? ?? 0.0;
    final assignedNgoId = c['assigned_ngo_id'] as String?;
    final dateStr = c['created_at'] != null
        ? DateFormat.jm().add_yMMMd().format(DateTime.parse(c['created_at']))
        : '';

    // AI details
    final aiAnalysis = c['ai_analysis'] as Map?;
    final animal = aiAnalysis?['animal'] as String? ?? 'Animal';
    final injuries = List<String>.from(aiAnalysis?['visible_injuries'] ?? []);

    final isAssignedToUs = assignedNgoId != null;

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
            // Top Header: Priority Badge, Match Score, Species
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
                        style: TextStyle(
                          color: priorityColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      animal.toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
                if (!isAssignedToUs && aiScore > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Match: ${aiScore.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        color: AppColors.secondary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else if (isAssignedToUs)
                  const Text(
                    'ASSIGNED',
                    style: TextStyle(
                      color: AppColors.secondary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Location
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
            const SizedBox(height: 8),

            // AI Injuries List
            if (injuries.isNotEmpty) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.healing_outlined, size: 16, color: AppColors.textHint),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'AI Injuries: ${injuries.join(", ")}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],

            // Date Reported
            Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: AppColors.textHint),
                const SizedBox(width: 8),
                Text(
                  'Reported: $dateStr',
                  style: const TextStyle(color: AppColors.textHint, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context.push(isAssignedToUs ? '/ngo/active/$caseId' : '/ngo/case/$caseId'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: AppColors.border),
                      foregroundColor: Colors.white,
                    ),
                    child: Text(isAssignedToUs ? 'MISSION TRACKER' : 'VIEW DETAILS'),
                  ),
                ),
                if (!isAssignedToUs) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Accept Rescue'),
                            content: const Text('Are you sure you want to accept this rescue case?'),
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
                          try {
                            await ref.read(rescueQueueProvider.notifier).accept(caseId);
                            if (context.mounted) {
                              context.push('/ngo/active/$caseId');
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to accept: $e')),
                              );
                            }
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: AppColors.primary,
                      ),
                      child: const Text('ACCEPT RESCUE'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
