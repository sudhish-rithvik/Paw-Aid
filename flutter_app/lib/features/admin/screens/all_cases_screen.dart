// lib/features/admin/screens/all_cases_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/services/api_service.dart';
import '../../../core/theme/app_theme.dart';

class AllCasesScreen extends ConsumerStatefulWidget {
  const AllCasesScreen({super.key});

  @override
  ConsumerState<AllCasesScreen> createState() => _AllCasesScreenState();
}

class _AllCasesScreenState extends ConsumerState<AllCasesScreen> {
  final _searchController = TextEditingController();
  String? _selectedStatus;
  String? _selectedSeverity;
  int _currentPage = 1;
  bool _isLoading = false;
  List<dynamic> _cases = [];
  int _totalCases = 0;

  final List<String> _statuses = [
    'pending', 'accepted', 'dispatched', 'animal_picked',
    'vet_treatment', 'recovery', 'completed', 'closed'
  ];

  final List<String> _severities = ['critical', 'high', 'medium', 'low'];

  @override
  void initState() {
    super.initState();
    _fetchCases();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchCases({bool reset = false}) async {
    if (reset) {
      setState(() {
        _currentPage = 1;
        _cases = [];
      });
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await ApiService.getAllCases(
        page: _currentPage,
        search: _searchController.text.trim().isNotEmpty ? _searchController.text.trim() : null,
        status: _selectedStatus,
        severity: _selectedSeverity,
      );

      setState(() {
        _cases.addAll(result['cases'] ?? []);
        _totalCases = result['total'] ?? 0;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load cases: $e')),
        );
      }
    }
  }

  void _loadMore() {
    if (_cases.length < _totalCases && !_isLoading) {
      setState(() {
        _currentPage++;
      });
      _fetchCases();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('City-Wide Case Monitor'),
      ),
      body: Column(
        children: [
          // Filter Panel
          Container(
            padding: const EdgeInsets.all(16),
            color: AppColors.surface,
            child: Column(
              children: [
                // Search bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by case ID or address...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: () => _fetchCases(reset: true),
                    ),
                  ),
                  onSubmitted: (_) => _fetchCases(reset: true),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    // Status Dropdown
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedStatus,
                        dropdownColor: AppColors.surface,
                        decoration: const InputDecoration(
                          labelText: 'Filter Status',
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('All Statuses')),
                          ..._statuses.map((s) => DropdownMenuItem(
                                value: s,
                                child: Text(s.replaceAll('_', ' ').toUpperCase()),
                              )),
                        ],
                        onChanged: (val) {
                          setState(() => _selectedStatus = val);
                          _fetchCases(reset: true);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Severity Dropdown
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedSeverity,
                        dropdownColor: AppColors.surface,
                        decoration: const InputDecoration(
                          labelText: 'Filter Severity',
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('All Severities')),
                          ..._severities.map((s) => DropdownMenuItem(
                                value: s,
                                child: Text(s.toUpperCase()),
                              )),
                        ],
                        onChanged: (val) {
                          setState(() => _selectedSeverity = val);
                          _fetchCases(reset: true);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Incidents count summary
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
            color: AppColors.surfaceVariant,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total Incidents: $_totalCases', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                if (_isLoading)
                  const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
          ),

          // Incidents List
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: (ScrollNotification scrollInfo) {
                if (scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
                  _loadMore();
                }
                return true;
              },
              child: RefreshIndicator(
                onRefresh: () => _fetchCases(reset: true),
                child: _cases.isEmpty && !_isLoading
                    ? ListView(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 100, horizontal: 24),
                            alignment: Alignment.center,
                            child: const Column(
                              children: [
                                Icon(Icons.search_off, size: 64, color: AppColors.textHint),
                                SizedBox(height: 16),
                                Text('No cases match your filters', style: TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(24),
                        itemCount: _cases.length + (_cases.length < _totalCases ? 1 : 0),
                        separatorBuilder: (_, __) => const SizedBox(height: 16),
                        itemBuilder: (ctx, index) {
                          if (index == _cases.length) {
                            return const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()));
                          }

                          final item = _cases[index] as Map<String, dynamic>;
                          final caseId = item['id'] as String;
                          final status = item['status'] as String? ?? 'pending';
                          final priority = item['priority_level'] as String? ?? 'medium';
                          final address = item['address'] as String? ?? 'Unknown location';
                          final dateStr = item['created_at'] != null
                              ? DateFormat.yMMMd().format(DateTime.parse(item['created_at']))
                              : '';

                          final priorityColor = switch (priority) {
                            'critical' => AppColors.critical,
                            'high' => AppColors.high,
                            'medium' => AppColors.medium,
                            'low' => AppColors.low,
                            _ => AppColors.textHint,
                          };

                          final statusColor = switch (status) {
                            'pending' => AppColors.warning,
                            'accepted' => AppColors.info,
                            'dispatched' => AppColors.info,
                            'animal_picked' => AppColors.primary,
                            'vet_treatment' => AppColors.primary,
                            'recovery' => AppColors.secondary,
                            'completed' => AppColors.success,
                            _ => AppColors.textSecondary,
                          };

                          return InkWell(
                            onTap: () => context.push('/track/$caseId'),
                            borderRadius: BorderRadius.circular(12),
                            child: Card(
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
                                              'CASE ${caseId.substring(0, 8).toUpperCase()}',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          status.replaceAll('_', ' ').toUpperCase(),
                                          style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
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
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Reported: $dateStr',
                                          style: const TextStyle(color: AppColors.textHint, fontSize: 11),
                                        ),
                                        const Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.primary),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
