// lib/data/repositories/photo_storage_repository.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../core/config/app_config.dart';
import '../../core/services/cloudinary_service.dart';

/// Photo Upload and Cloud Storage Status
/// Designed for zero-cost compliance on Firebase Spark.
enum PhotoUploadStatus {
  /// Stored only on user's device. No cloud storage used.
  localOnly,

  /// Stored locally; cloud upload deferred until a verified free-tier storage provider is enabled.
  pendingStorageProvider,

  /// Uploaded to cloud storage (e.g. Cloudinary free tier).
  uploaded,

  /// Upload failed.
  failed;

  String get displayName => switch (this) {
        PhotoUploadStatus.localOnly => 'Local Storage Only (Device)',
        PhotoUploadStatus.pendingStorageProvider => 'Pending Cloud Storage (\$0.00 Spark Mode)',
        PhotoUploadStatus.uploaded => 'Cloud Stored (Cloudinary CDN)',
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
  /// Save a captured photo locally on the device or upload to free CDN
  Future<String> saveLocalPhoto({
    required String sourcePath,
    required String reportId,
  });

  /// Retrieve the locally accessible file path or remote URL for a photo reference
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

/// Cloudinary Photo Storage Repository
/// Attempts direct upload to Cloudinary free tier CDN.
/// Falls back safely to local device storage if offline or unconfigured.
class CloudinaryPhotoStorageRepository implements PhotoStorageRepository {
  const CloudinaryPhotoStorageRepository();

  @override
  bool get isCloudStorageConfigured => AppConfig.isCloudinaryConfigured;

  @override
  Future<String> saveLocalPhoto({
    required String sourcePath,
    required String reportId,
  }) async {
    // 1. Attempt Cloudinary upload if configured
    if (AppConfig.isCloudinaryConfigured) {
      try {
        final file = File(sourcePath);
        final remoteUrl = await CloudinaryService.uploadImage(
          file: file,
          publicId: 'paw_aid_$reportId',
        );
        if (remoteUrl != null && remoteUrl.isNotEmpty) {
          return remoteUrl;
        }
      } catch (e) {
        debugPrint('[CloudinaryPhotoStorageRepository] Cloudinary upload deferred: $e');
      }
    }

    // 2. Safe Fallback to local storage
    try {
      final file = File(sourcePath);
      if (await file.exists()) {
        return file.path;
      }
    } catch (_) {}

    return sourcePath;
  }

  @override
  Future<String?> getPhotoLocalPath(String photoReference) async {
    if (photoReference.isEmpty) return null;
    if (photoReference.startsWith('http://') || photoReference.startsWith('https://')) {
      return photoReference;
    }
    final file = File(photoReference);
    if (await file.exists()) {
      return file.path;
    }
    return photoReference;
  }

  @override
  Future<PhotoUploadStatus> getUploadStatus(String photoReference) async {
    if (photoReference.startsWith('http://') || photoReference.startsWith('https://')) {
      return PhotoUploadStatus.uploaded;
    }
    return PhotoUploadStatus.pendingStorageProvider;
  }

  @override
  Future<bool> deletePhoto(String photoReference) async {
    try {
      if (!photoReference.startsWith('http')) {
        final file = File(photoReference);
        if (await file.exists()) {
          await file.delete();
          return true;
        }
      }
    } catch (_) {}
    return false;
  }
}
