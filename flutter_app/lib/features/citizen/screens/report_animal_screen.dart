// lib/features/citizen/screens/report_animal_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/services/api_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/report_provider.dart';

class ReportAnimalScreen extends ConsumerStatefulWidget {
  const ReportAnimalScreen({super.key});

  @override
  ConsumerState<ReportAnimalScreen> createState() => _ReportAnimalScreenState();
}

class _ReportAnimalScreenState extends ConsumerState<ReportAnimalScreen> {
  final _notesController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  XFile? _imageFile;
  LatLng? _currentLocation;
  bool _isLocating = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _autoCaptureLocation();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _autoCaptureLocation() async {
    setState(() {
      _isLocating = true;
      _errorMessage = null;
    });

    try {
      final loc = await LocationService.getCurrentLocation();
      if (mounted) {
        setState(() {
          _currentLocation = loc;
          _isLocating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLocating = false;
          _errorMessage = 'Could not retrieve GPS location. Please check location permissions.';
        });
      }
    }
  }

  Future<void> _captureImage(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (file != null) {
        setState(() {
          _imageFile = file;
        });
      }
    } catch (_) {}
  }

  Future<void> _submitReport() async {
    if (_imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please capture or select a photo first.')),
      );
      return;
    }

    if (_currentLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please wait for GPS coordinates to load.')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final session = SupabaseService.auth.currentSession;
      final userId = session?.user.id;

      final result = await ApiService.submitReport(
        imagePath: _imageFile!.path,
        lat: _currentLocation!.latitude,
        lng: _currentLocation!.longitude,
        notes: _notesController.text.trim(),
        userId: userId,
      );

      // Invalidate myReports provider so list gets updated
      ref.invalidate(myReportsProvider);

      final caseId = result['case_id'] as String;
      if (mounted) {
        // Navigate to track rescue screen
        context.go('/track/$caseId');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Injured Animal'),
      ),
      body: _isSubmitting
          ? _buildSubmittingView()
          : SingleChildScrollView(
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
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: AppColors.critical, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ).animate().shake(),
                    const SizedBox(height: 20),
                  ],

                  // Step 1: Photo Capture
                  _buildSectionTitle('1. CAPTURE PHOTO', Icons.camera_alt_outlined),
                  const SizedBox(height: 12),
                  _buildPhotoPlaceholder(),
                  const SizedBox(height: 24),

                  // Step 2: Location
                  _buildSectionTitle('2. RESCUE LOCATION', Icons.location_on_outlined),
                  const SizedBox(height: 12),
                  _buildLocationCard(),
                  const SizedBox(height: 24),

                  // Step 3: Notes
                  _buildSectionTitle('3. ADDITIONAL DETAILS (OPTIONAL)', Icons.edit_note_outlined),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Describe injuries, animal behavior, or directions to locate...',
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Submit CTA
                  ElevatedButton(
                    onPressed: (_imageFile == null || _currentLocation == null) ? null : _submitReport,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppColors.primary,
                    ),
                    child: const Text('SUBMIT EMERGENCY REPORT'),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoPlaceholder() {
    if (_imageFile != null) {
      return Stack(
        alignment: Alignment.topRight,
        children: [
          Container(
            height: 220,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
              image: DecorationImage(
                image: FileImage(File(_imageFile!.path)),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: CircleAvatar(
              backgroundColor: Colors.black.withOpacity(0.6),
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => setState(() => _imageFile = null),
              ),
            ),
          ),
        ],
      );
    }

    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.pets, size: 48, color: AppColors.textHint),
          const SizedBox(height: 16),
          const Text('Take or select a photo of the animal', style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () => _captureImage(ImageSource.camera),
                icon: const Icon(Icons.camera_alt, size: 16),
                label: const Text('CAMERA', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () => _captureImage(ImageSource.gallery),
                icon: const Icon(Icons.image, size: 16),
                label: const Text('GALLERY', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  side: const BorderSide(color: AppColors.border),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (_currentLocation != null ? AppColors.secondary : AppColors.warning).withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _currentLocation != null ? Icons.gps_fixed : Icons.gps_not_fixed,
              color: _currentLocation != null ? AppColors.secondary : AppColors.warning,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _currentLocation != null ? 'GPS Signal Acquired' : 'Acquiring GPS Signal...',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  _currentLocation != null
                      ? 'Lat: ${_currentLocation!.latitude.toStringAsFixed(5)}, Lng: ${_currentLocation!.longitude.toStringAsFixed(5)}'
                      : 'Retrieving coordinates...',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          if (_isLocating)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh, color: AppColors.primary, size: 20),
              onPressed: _autoCaptureLocation,
              tooltip: 'Refresh GPS',
            ),
        ],
      ),
    );
  }

  Widget _buildSubmittingView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 64,
              height: 64,
              child: CircularProgressIndicator(strokeWidth: 4),
            ).animate().rotate(duration: 2000.ms),
            const SizedBox(height: 24),
            Text(
              'Submitting Report...',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Uploading image and starting the AI Analysis pipeline. Please wait, do not close the app.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
