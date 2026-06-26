// lib/features/ngo/screens/stage_updater.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/services/api_service.dart';
import '../../../core/theme/app_theme.dart';

/// Standalone screen for NGO to update a rescue case stage + optional photo.
class StageUpdaterScreen extends ConsumerStatefulWidget {
  final String caseId;
  const StageUpdaterScreen({super.key, required this.caseId});

  @override
  ConsumerState<StageUpdaterScreen> createState() =>
      _StageUpdaterScreenState();
}

class _StageUpdaterScreenState extends ConsumerState<StageUpdaterScreen> {
  String? _selectedNextStatus;
  XFile? _stagePhoto;
  bool _isUpdating = false;
  bool _isDone = false;
  final _notesController = TextEditingController();
  final _picker = ImagePicker();

  /// The ordered stages an NGO can advance through (after accepted)
  static const _stages = [
    ('dispatched', 'Team Dispatched 🚗', 'Mark your team as en route'),
    ('animal_picked', 'Animal Picked Up 🐾', 'Animal is secured in vehicle'),
    ('vet_treatment', 'Vet Treatment 🏥', 'Animal receiving medical care'),
    ('recovery', 'In Recovery 💊', 'Animal is stable, under observation'),
    ('completed', 'Rescue Completed ❤️', 'Mark as fully resolved'),
  ];

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final file = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );
    if (file != null) setState(() => _stagePhoto = file);
  }

  Future<void> _submit() async {
    if (_selectedNextStatus == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select the next stage')),
      );
      return;
    }

    setState(() => _isUpdating = true);

    try {
      // Upload stage photo if provided
      List<int>? imageBytes;
      if (_stagePhoto != null) {
        imageBytes = await File(_stagePhoto!.path).readAsBytes();
      }

      // Update case status via API
      await ApiService.updateCaseStatus(
        widget.caseId,
        _selectedNextStatus!,
        imageBytes: imageBytes,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      if (mounted) setState(() => _isDone = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update failed: $e')),
        );
        setState(() => _isUpdating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Update Rescue Stage')),
      body: _isDone ? _buildSuccess() : _buildForm(),
    );
  }

  Widget _buildSuccess() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle,
                size: 72, color: AppColors.success),
          ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
          const SizedBox(height: 24),
          Text('Stage Updated!',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text('Citizen will be notified via push.',
              style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => context.pop(),
            child: const Text('BACK TO ACTIVE RESCUE'),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Stage selector
          Text('Select Next Stage',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),

          ..._stages.map((stage) {
            final (value, label, desc) = stage;
            final isSelected = _selectedNextStatus == value;
            return GestureDetector(
              onTap: () => setState(() => _selectedNextStatus = value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withOpacity(0.1)
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.cardBorder,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Radio<String>(
                      value: value,
                      groupValue: _selectedNextStatus,
                      onChanged: (v) =>
                          setState(() => _selectedNextStatus = v),
                      activeColor: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.textSecondary,
                              )),
                          Text(desc,
                              style: const TextStyle(
                                  color: AppColors.textHint, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 24),

          // Photo capture
          Text('Stage Photo (optional)',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),

          if (_stagePhoto != null)
            Stack(
              alignment: Alignment.topRight,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(File(_stagePhoto!.path),
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: CircleAvatar(
                    backgroundColor: Colors.black54,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => setState(() => _stagePhoto = null),
                    ),
                  ),
                ),
              ],
            )
          else
            OutlinedButton.icon(
              onPressed: _pickPhoto,
              icon: const Icon(Icons.camera_alt),
              label: const Text('TAKE PHOTO'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: AppColors.border),
                foregroundColor: Colors.white,
              ),
            ),

          const SizedBox(height: 20),

          // Notes
          TextFormField(
            controller: _notesController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Stage Notes (optional)',
              hintText: 'Any relevant update for the citizen...',
            ),
          ),

          const SizedBox(height: 32),

          ElevatedButton(
            onPressed: _isUpdating ? null : _submit,
            style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16)),
            child: _isUpdating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text('UPDATE STAGE & NOTIFY CITIZEN'),
          ),
        ],
      ),
    );
  }
}
