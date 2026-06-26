// lib/features/admin/screens/ngo_detail_admin_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/admin_provider.dart';

class NGODetailAdminScreen extends ConsumerStatefulWidget {
  final String ngoId;
  const NGODetailAdminScreen({super.key, required this.ngoId});

  @override
  ConsumerState<NGODetailAdminScreen> createState() => _NGODetailAdminScreenState();
}

class _NGODetailAdminScreenState extends ConsumerState<NGODetailAdminScreen> {
  Map<String, dynamic>? _ngoDetail;
  List<dynamic> _documents = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _fetchNGODetails();
  }

  Future<void> _fetchNGODetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final detail = await ApiService.getNGODetail(widget.ngoId);
      setState(() {
        _ngoDetail = detail['ngo'] ?? detail;
        _documents = detail['documents'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _handleApprove() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve NGO'),
        content: const Text('Are you sure you want to approve this organization? This will activate their credentials and enable them to accept rescues.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('APPROVE', style: TextStyle(color: AppColors.secondary)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isProcessing = true);
      try {
        await ref.read(nGOVerificationNotifierProvider.notifier).approve(widget.ngoId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('NGO approved successfully. Email notification sent.')),
          );
          context.pop();
        }
      } catch (e) {
        setState(() => _isProcessing = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Verification error: $e')),
          );
        }
      }
    }
  }

  Future<void> _handleReject() async {
    final reasonController = TextEditingController();
    final reject = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Registration'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Please specify a rejection reason. This will be emailed to the organization:'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'e.g. Missing valid PAN card/license info...',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('REJECT', style: TextStyle(color: AppColors.critical)),
          ),
        ],
      ),
    );

    if (reject == true && reasonController.text.trim().isNotEmpty) {
      setState(() => _isProcessing = true);
      try {
        await ref.read(nGOVerificationNotifierProvider.notifier).reject(
              widget.ngoId,
              reasonController.text.trim(),
            );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('NGO registration rejected. Notification email dispatched.')),
          );
          context.pop();
        }
      } catch (e) {
        setState(() => _isProcessing = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Rejection error: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null || _ngoDetail == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Verify NGO')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: AppColors.critical),
                const SizedBox(height: 16),
                Text('Error: ${_errorMessage ?? "Unable to load details."}', textAlign: TextAlign.center),
                const SizedBox(height: 24),
                ElevatedButton(onPressed: _fetchNGODetails, child: const Text('RETRY')),
              ],
            ),
          ),
        ),
      );
    }

    final ngo = _ngoDetail!;
    final name = ngo['name'] as String? ?? 'NGO';
    final regNum = ngo['registration_number'] as String? ?? 'N/A';
    final email = ngo['email'] as String? ?? 'N/A';
    final phone = ngo['phone'] as String? ?? 'N/A';
    final city = ngo['city'] as String? ?? 'Unknown';
    final state = ngo['state'] as String? ?? '';
    final vehicles = ngo['num_vehicles'] ?? 0;
    final volunteers = ngo['num_volunteers'] ?? 0;
    final radius = ngo['service_radius_km'] ?? 25.0;
    final hours = ngo['operating_hours'] ?? '24/7';
    final List<dynamic> specs = ngo['specializations'] ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify NGO Credentials'),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // NGO Main header
                Text(
                  name,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text('Registration Code: $regNum', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                const SizedBox(height: 24),

                // Step 1: Contact Card
                _buildHeader('Contact Information'),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        _buildDetailRow('Email', email, Icons.email_outlined),
                        const Divider(height: 24),
                        _buildDetailRow('Phone', phone, Icons.phone_outlined),
                        const Divider(height: 24),
                        _buildDetailRow('Location', '$city, $state', Icons.location_on_outlined),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Step 2: Capacity Card
                _buildHeader('Capacity & Range'),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        _buildDetailRow('Rescue Vehicles', '$vehicles active vehicles', Icons.local_shipping_outlined),
                        const Divider(height: 24),
                        _buildDetailRow('Active Volunteers', '$volunteers volunteers', Icons.people_outline),
                        const Divider(height: 24),
                        _buildDetailRow('Service Radius', '${radius} km coverage', Icons.explore_outlined),
                        const Divider(height: 24),
                        _buildDetailRow('Operating Hours', '$hours', Icons.access_time),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Step 3: Specializations
                if (specs.isNotEmpty) ...[
                  _buildHeader('Species Capabilities'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: specs.map((spec) {
                      final display = spec.toString()[0].toUpperCase() + spec.toString().substring(1);
                      return Chip(label: Text(display));
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                ],

                // Step 4: Documents list
                _buildHeader('Uploaded Documents Verification'),
                const SizedBox(height: 12),
                if (_documents.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Center(
                        child: Text(
                          'No documents uploaded for this organization.',
                          style: TextStyle(color: AppColors.textHint, fontSize: 13),
                        ),
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _documents.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (ctx, index) {
                      final doc = _documents[index] as Map<String, dynamic>;
                      final docType = doc['doc_type'] as String? ?? 'Document';
                      final storagePath = doc['storage_path'] as String;

                      final docUrl = SupabaseService.getPublicUrl('ngo-documents', storagePath);

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.description_outlined, color: AppColors.primary),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      docType.replaceAll('_', ' ').toUpperCase(),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text('Click View to open certificate file', style: TextStyle(color: AppColors.textHint, fontSize: 11)),
                                  ],
                                ),
                              ],
                            ),
                            ElevatedButton(
                              onPressed: () async {
                                final Uri uri = Uri.parse(docUrl);
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.surfaceVariant,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              ),
                              child: const Text('VIEW', style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 48),

                // Approval CTAs
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _handleReject,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.critical,
                          side: const BorderSide(color: AppColors.critical),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('REJECT REGISTRATION'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _handleApprove,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondary,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('APPROVE NGO'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
          if (_isProcessing)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Processing verification updates...', style: TextStyle(color: Colors.white, decoration: TextDecoration.none, fontSize: 14)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(String title) {
    return Text(
      title,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white, letterSpacing: 0.5),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.textSecondary),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textHint, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 13, color: Colors.white, height: 1.3)),
            ],
          ),
        ),
      ],
    );
  }
}
