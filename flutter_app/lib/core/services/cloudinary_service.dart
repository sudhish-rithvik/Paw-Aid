// lib/core/services/cloudinary_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

/// Cloudinary Service
/// Provides direct client-side photo uploading to Cloudinary free CDN via unsigned upload presets.
/// Requires zero credit card, zero cloud billing, and zero paid infrastructure.
class CloudinaryService {
  CloudinaryService._();

  static const String _baseUrl = 'https://api.cloudinary.com/v1_1';

  /// Whether Cloudinary credentials are valid and ready
  static bool get isAvailable => AppConfig.isCloudinaryConfigured;

  /// Upload an animal incident image directly to Cloudinary CDN.
  ///
  /// Returns the secure HTTPS URL (e.g. `https://res.cloudinary.com/.../image.jpg`) on success.
  /// Returns `null` on failure, network disconnect, or if credentials are not configured.
  static Future<String?> uploadImage({
    required File file,
    String? publicId,
    String? folder,
  }) async {
    if (!AppConfig.isCloudinaryConfigured) {
      debugPrint('[CloudinaryService] Cloudinary credentials not configured yet. Fallback to local/base64.');
      return null;
    }

    if (!await file.exists()) {
      debugPrint('[CloudinaryService] File does not exist at: ${file.path}');
      return null;
    }

    try {
      final cloudName = AppConfig.cloudinaryCloudName.trim();
      final uploadPreset = AppConfig.cloudinaryUploadPreset.trim();
      final uploadFolder = folder ?? AppConfig.cloudinaryFolder;

      final url = Uri.parse('$_baseUrl/$cloudName/image/upload');
      debugPrint('[CloudinaryService] Uploading incident photo to $url...');

      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = uploadPreset
        ..fields['folder'] = uploadFolder;

      if (publicId != null && publicId.isNotEmpty) {
        request.fields['public_id'] = publicId;
      }

      // Add file as multipart
      final multipartFile = await http.MultipartFile.fromPath('file', file.path);
      request.files.add(multipartFile);

      final streamedResponse = await request.send().timeout(const Duration(seconds: 25));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final secureUrl = data['secure_url'] as String?;
        debugPrint('[CloudinaryService] Upload succeeded! Public URL: $secureUrl');
        return secureUrl;
      } else {
        debugPrint('[CloudinaryService] Upload failed with HTTP ${response.statusCode}: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('[CloudinaryService] Exception during upload: $e');
      return null;
    }
  }
}
