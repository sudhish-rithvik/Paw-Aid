// lib/features/ngo/screens/ngo_registration_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/services/api_service.dart';
import '../../../core/theme/app_theme.dart';

class NGORegistrationScreen extends StatefulWidget {
  const NGORegistrationScreen({super.key});

  @override
  State<NGORegistrationScreen> createState() => _NGORegistrationScreenState();
}

class _NGORegistrationScreenState extends State<NGORegistrationScreen> {
  int _currentStep = 0;
  bool _isLoading = false;
  bool _isSuccess = false;
  String? _errorMessage;

  // Form keys
  final _step1Key = GlobalKey<FormState>();
  final _step3Key = GlobalKey<FormState>();

  // Step 1: Org Details
  final _nameController = TextEditingController();
  final _regNumController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();

  // Step 2: Documents (Paths / files)
  final ImagePicker _picker = ImagePicker();
  XFile? _regCert;
  XFile? _welfareLicense;
  XFile? _panCard;
  XFile? _idProof;

  // Step 3: Capacity
  final _vehiclesController = TextEditingController(text: '0');
  final _volunteersController = TextEditingController(text: '0');
  final _radiusController = TextEditingController(text: '25');
  String _operatingHours = '24/7';

  // Step 4: Specializations
  final List<String> _availableSpecs = ['dogs', 'cats', 'birds', 'cattle', 'wildlife'];
  final List<String> _selectedSpecs = [];

  @override
  void dispose() {
    _nameController.dispose();
    _regNumController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _vehiclesController.dispose();
    _volunteersController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  Future<void> _pickDocument(String docType) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (file != null) {
        setState(() {
          switch (docType) {
            case 'regCert':
              _regCert = file;
              break;
            case 'welfareLicense':
              _welfareLicense = file;
              break;
            case 'pan':
              _panCard = file;
              break;
            case 'idProof':
              _idProof = file;
              break;
          }
        });
      }
    } catch (_) {}
  }

  void _nextStep() {
    if (_currentStep == 0) {
      if (!_step1Key.currentState!.validate()) return;
    } else if (_currentStep == 1) {
      if (_regCert == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please upload at least your Registration Certificate')),
        );
        return;
      }
    } else if (_currentStep == 2) {
      if (!_step3Key.currentState!.validate()) return;
    } else if (_currentStep == 3) {
      if (_selectedSpecs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select at least one animal specialization')),
        );
        return;
      }
      _submitRegistration();
      return;
    }

    setState(() {
      _currentStep++;
    });
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    }
  }

  Future<void> _submitRegistration() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Package the basic fields
      final Map<String, dynamic> data = {
        'name': _nameController.text.trim(),
        'registration_number': _regNumController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
        'specializations': _selectedSpecs.join(','),
        'num_vehicles': int.tryParse(_vehiclesController.text) ?? 0,
        'num_volunteers': int.tryParse(_volunteersController.text) ?? 0,
        'service_radius_km': double.tryParse(_radiusController.text) ?? 25.0,
        'operating_hours': _operatingHours,
      };

      // 2. Package the files
      final List<Map<String, dynamic>> documents = [];
      if (_regCert != null) {
        final bytes = await _regCert!.readAsBytes();
        documents.add({
          'bytes': bytes,
          'filename': _regCert!.name,
          'type': 'registration_cert',
        });
      }
      if (_welfareLicense != null) {
        final bytes = await _welfareLicense!.readAsBytes();
        documents.add({
          'bytes': bytes,
          'filename': _welfareLicense!.name,
          'type': 'animal_welfare_license',
        });
      }
      if (_panCard != null) {
        final bytes = await _panCard!.readAsBytes();
        documents.add({
          'bytes': bytes,
          'filename': _panCard!.name,
          'type': 'pan',
        });
      }
      if (_idProof != null) {
        final bytes = await _idProof!.readAsBytes();
        documents.add({
          'bytes': bytes,
          'filename': _idProof!.name,
          'type': 'id_proof',
        });
      }

      await ApiService.registerNGO(data, documents);

      setState(() {
        _isLoading = false;
        _isSuccess = true;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isSuccess) {
      return _buildSuccessScreen();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Register NGO'),
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Uploading documents and registering org...',
                      style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            )
          : Column(
              children: [
                // Top Progress indicator
                _buildProgressHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.critical.withOpacity(0.15),
                              border: Border.all(color: AppColors.critical.withOpacity(0.3)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, color: AppColors.critical),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(_errorMessage!,
                                      style: const TextStyle(color: AppColors.critical, fontSize: 13)),
                                ),
                              ],
                            ),
                          ).animate().shake(),
                          const SizedBox(height: 20),
                        ],
                        _buildStepContent(),
                        const SizedBox(height: 40),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (_currentStep > 0)
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _prevStep,
                                  child: const Text('BACK'),
                                ),
                              )
                            else
                              const Spacer(),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _nextStep,
                                child: Text(_currentStep == 3 ? 'SUBMIT' : 'NEXT'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildProgressHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      color: AppColors.surface,
      child: Row(
        children: List.generate(4, (index) {
          final isCompleted = index < _currentStep;
          final isCurrent = index == _currentStep;
          return Expanded(
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? AppColors.secondary
                        : isCurrent
                            ? AppColors.primary
                            : AppColors.surfaceVariant,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(Icons.check, size: 18, color: Colors.black)
                        : Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: isCurrent ? Colors.white : AppColors.textHint,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                if (index < 3)
                  Expanded(
                    child: Container(
                      height: 2,
                      color: isCompleted ? AppColors.secondary : AppColors.divider,
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return Form(
          key: _step1Key,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStepTitle('Organization Details', 'Enter basic contact and verification info'),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'NGO Name',
                  prefixIcon: Icon(Icons.business_outlined),
                ),
                validator: (value) => value == null || value.trim().isEmpty ? 'Enter NGO name' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _regNumController,
                decoration: const InputDecoration(
                  labelText: 'Registration / License Number',
                  prefixIcon: Icon(Icons.assignment_ind_outlined),
                ),
                validator: (value) => value == null || value.trim().isEmpty ? 'Enter registration number' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Official Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Enter email';
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) return 'Enter valid email';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Helpline / Contact Phone',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                validator: (value) => value == null || value.trim().isEmpty ? 'Enter phone number' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _cityController,
                      decoration: const InputDecoration(
                        labelText: 'City',
                      ),
                      validator: (value) => value == null || value.trim().isEmpty ? 'Enter city' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _stateController,
                      decoration: const InputDecoration(
                        labelText: 'State',
                      ),
                      validator: (value) => value == null || value.trim().isEmpty ? 'Enter state' : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );

      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStepTitle('Upload Documents', 'Attach photos of registration and identification'),
            const SizedBox(height: 24),
            _buildDocPickerTile('Registration Certificate *', _regCert, () => _pickDocument('regCert')),
            const SizedBox(height: 16),
            _buildDocPickerTile('Animal Welfare Board License', _welfareLicense, () => _pickDocument('welfareLicense')),
            const SizedBox(height: 16),
            _buildDocPickerTile('NGO PAN Card', _panCard, () => _pickDocument('pan')),
            const SizedBox(height: 16),
            _buildDocPickerTile('Authorized Person ID Proof', _idProof, () => _pickDocument('idProof')),
          ],
        );

      case 2:
        return Form(
          key: _step3Key,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStepTitle('Rescue Capacity', 'Define your scale of operations'),
              const SizedBox(height: 24),
              TextFormField(
                controller: _vehiclesController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Number of Active Vehicles',
                  prefixIcon: Icon(Icons.local_shipping_outlined),
                ),
                validator: (value) => value == null || int.tryParse(value) == null ? 'Enter valid number' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _volunteersController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Number of Registered Volunteers',
                  prefixIcon: Icon(Icons.people_outline),
                ),
                validator: (value) => value == null || int.tryParse(value) == null ? 'Enter valid number' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _radiusController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Service Radius (in Kilometers)',
                  prefixIcon: Icon(Icons.explore_outlined),
                  suffixText: 'km',
                ),
                validator: (value) => value == null || double.tryParse(value) == null ? 'Enter valid distance' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _operatingHours,
                decoration: const InputDecoration(
                  labelText: 'Operating Hours',
                  prefixIcon: Icon(Icons.access_time),
                ),
                items: ['24/7', 'Daytime only (8 AM - 8 PM)', 'Custom shift']
                    .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _operatingHours = val;
                    });
                  }
                },
              ),
            ],
          ),
        );

      case 3:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStepTitle('Species Specializations', 'Select species your team is equipped to rescue'),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _availableSpecs.map((spec) {
                final isSelected = _selectedSpecs.contains(spec);
                final String display = spec[0].toUpperCase() + spec.substring(1);
                final String emoji = switch (spec) {
                  'dogs' => '🐕',
                  'cats' => '🐈',
                  'birds' => '🦅',
                  'cattle' => '🐄',
                  'wildlife' => '🦊',
                  _ => '🐾',
                };
                return FilterChip(
                  label: Text('$emoji $display'),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedSpecs.add(spec);
                      } else {
                        _selectedSpecs.remove(spec);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ],
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStepTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      ],
    );
  }

  Widget _buildDocPickerTile(String label, XFile? file, VoidCallback onTap) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 4),
                Text(
                  file != null ? file.name : 'No file uploaded',
                  style: TextStyle(
                    color: file != null ? AppColors.secondary : AppColors.textHint,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: onTap,
            icon: Icon(file != null ? Icons.cached : Icons.upload_file, size: 16),
            label: Text(file != null ? 'CHANGE' : 'SELECT', style: const TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              backgroundColor: file != null ? AppColors.surfaceVariant : AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessScreen() {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.secondary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.verified_outlined, size: 56, color: AppColors.secondary),
              ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
              const SizedBox(height: 24),
              Text(
                'Registration Submitted!',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Thank you for registering your organization. We are currently verifying your credentials. An email confirmation has been sent to your official address.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () => context.go('/login'),
                child: const Text('BACK TO LOGIN'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
