// lib/features/citizen/screens/volunteer_signup.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';

class VolunteerSignupScreen extends ConsumerStatefulWidget {
  const VolunteerSignupScreen({super.key});

  @override
  ConsumerState<VolunteerSignupScreen> createState() =>
      _VolunteerSignupScreenState();
}

class _VolunteerSignupScreenState
    extends ConsumerState<VolunteerSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _selectedNgoId;
  List<Map<String, dynamic>> _ngos = [];
  bool _isLoading = false;
  bool _isSubmitted = false;

  @override
  void initState() {
    super.initState();
    _loadNGOs();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadNGOs() async {
    try {
      final result = await SupabaseService.client
          .from('ngos')
          .select('id, name, city')
          .eq('status', 'approved')
          .order('name');
      if (mounted) {
        setState(() {
          _ngos = List<Map<String, dynamic>>.from(result as List);
        });
      }
    } catch (_) {}
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final user = SupabaseService.auth.currentUser;
      await SupabaseService.client.from('volunteers').insert({
        'profile_id': user?.id,
        'ngo_id': _selectedNgoId,
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'is_available': true,
      });
      if (mounted) setState(() => _isSubmitted = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Volunteer Signup')),
      body: _isSubmitted ? _buildSuccess() : _buildForm(),
    );
  }

  Widget _buildSuccess() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.favorite,
                  size: 64, color: AppColors.success),
            ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
            const SizedBox(height: 24),
            Text(
              'Welcome, Volunteer! 🐾',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 300.ms),
            const SizedBox(height: 12),
            const Text(
              'Your volunteer request has been submitted. The NGO team will contact you soon.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.textSecondary, height: 1.5),
            ).animate().fadeIn(delay: 500.ms),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => context.go('/citizen/home'),
              child: const Text('GO TO HOME'),
            ).animate().fadeIn(delay: 700.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hero section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.secondary.withOpacity(0.15),
                    AppColors.secondary.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppColors.secondary.withOpacity(0.2)),
              ),
              child: const Column(
                children: [
                  Icon(Icons.volunteer_activism,
                      size: 48, color: AppColors.secondary),
                  SizedBox(height: 12),
                  Text(
                    'Become a Field Volunteer',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Help NGOs on the ground. You\'ll be notified of nearby rescue operations.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 500.ms),

            const SizedBox(height: 32),

            // Form fields
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(Icons.person_outlined),
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Name is required' : null,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              validator: (v) =>
                  v == null || v.length < 10 ? 'Enter valid phone' : null,
            ),
            const SizedBox(height: 16),

            // NGO selector
            DropdownButtonFormField<String>(
              value: _selectedNgoId,
              decoration: const InputDecoration(
                labelText: 'Preferred NGO (optional)',
                prefixIcon: Icon(Icons.business_outlined),
              ),
              dropdownColor: AppColors.surface,
              items: _ngos
                  .map((ngo) => DropdownMenuItem(
                        value: ngo['id'] as String,
                        child: Text(
                          '${ngo['name']} — ${ngo['city'] ?? ''}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ))
                  .toList(),
              onChanged: (val) => setState(() => _selectedNgoId = val),
            ),

            const SizedBox(height: 32),

            // Benefits
            const Text(
              'As a volunteer you can:',
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            ...[
              '🚗 Respond to nearby rescue calls',
              '📸 Document and update rescue stages',
              '🏥 Transport animals to clinics',
              '📊 Track your rescue contributions',
            ].map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(t,
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13))),
                    ],
                  ),
                )),

            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppColors.secondary),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.black, strokeWidth: 2))
                  : const Text('SUBMIT VOLUNTEER REQUEST',
                      style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}
