// lib/data/repositories/photo_storage_repository.dart
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Photo Upload and Cloud Storage Status
/// Designed for zero-cost compliance on Firebase Spark.
enum PhotoUploadStatus {
  /// Stored only on user's device. No cloud storage used.
  localOnly,

  /// Stored locally; cloud upload deferred until a verified free-tier storage provider is enabled.
  pendingStorageProvider,

  /// Uploaded to cloud storage (when a non-billing provider is integrated).
  uploaded,

  /// Upload failed.
  failed;

  String get displayName => switch (this) {
        PhotoUploadStatus.localOnly => 'Local Storage Only (Device)',
        PhotoUploadStatus.pendingStorageProvider => 'Pending Cloud Storage (\$0.00 Spark Mode)',
        PhotoUploadStatus.uploaded => 'Cloud Stored',
        PhotoUploadStatus.failed => 'Upload Failed',
      };

  static PhotoUploadStatus fromString(String? val) {
    if (val == null) return PhotoUploadStatus.localOnly;
    return PhotoUploadStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == val.toLowerCase(),
      orElse: () => PhotoUploadStatus.localOnly,
    );
  }
}

/// Abstract Photo Storage Repository
/// Decouples photo persistence from paid cloud storage engines.
/// Strictly adheres to Firebase Spark: NO firebase_storage, NO Base64 blobs in Firestore.
abstract class PhotoStorageRepository {
  /// Save a captured photo locally on the device for this report
  Future<String> saveLocalPhoto({
    required String sourcePath,
    required String reportId,
  });

  /// Retrieve the locally accessible file path for a photo reference
  Future<String?> getPhotoLocalPath(String photoReference);

  /// Check upload status
  Future<PhotoUploadStatus> getUploadStatus(String photoReference);

  /// Delete local photo cache
  Future<bool> deletePhoto(String photoReference);

  /// Indicates whether a remote cloud storage backend is configured
  bool get isCloudStorageConfigured;
}

/// Local Device Implementation of PhotoStorageRepository
class LocalPhotoStorageRepository implements PhotoStorageRepository {
  const LocalPhotoStorageRepository();

  @override
  bool get isCloudStorageConfigured => false;

  @override
  Future<String> saveLocalPhoto({
    required String sourcePath,
    required String reportId,
  }) async {
    try {
      final file = File(sourcePath);
      if (await file.exists()) {
        // Return file path as the persistent local reference
        return file.path;
      }
      return sourcePath;
    } catch (e) {
      debugPrint('[LocalPhotoStorageRepository] saveLocalPhoto error: $e');
      return sourcePath;
    }
  }

  @override
  Future<String?> getPhotoLocalPath(String photoReference) async {
    if (photoReference.isEmpty) return null;
    final file = File(photoReference);
    if (await file.exists()) {
      return file.path;
    }
    return photoReference;
  }

  @override
  Future<PhotoUploadStatus> getUploadStatus(String photoReference) async {
    return PhotoUploadStatus.pendingStorageProvider;
  }

  @override
  Future<bool> deletePhoto(String photoReference) async {
    try {
      final file = File(photoReference);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
    } catch (_) {}
    return false;
  }
}
