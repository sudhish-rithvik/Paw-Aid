// lib/core/config/app_config.dart

/// Global Application Configuration
class AppConfig {
  AppConfig._();

  static const String appName = 'PAW-AID';
  static const String appVersion = '1.0.0+1';

  /// Spark Tier Strict Enforcement Flag:
  /// When true, prevents any code path from invoking paid cloud endpoints or Blaze features.
  static const bool sparkPlanOnly = true;

  /// Offline exhibition demo mode fallback enabled
  static const bool offlineDemoFallbackEnabled = true;

  // ── Cloudinary Configuration (100% Free CDN Image Hosting) ──────────────────
  // Sign up for free at https://cloudinary.com (No credit card required).
  // Under Cloudinary Console:
  // 1. Copy your "Cloud name".
  // 2. Go to Settings -> Upload -> Upload presets -> Add upload preset.
  // 3. Set "Signing Mode" to "Unsigned" and give it a name (e.g. "paw_aid_cases").
  static const String cloudinaryCloudName = String.fromEnvironment(
    'CLOUDINARY_CLOUD_NAME',
    defaultValue: 'lrxxgm5n', // Configured Cloudinary Cloud Name
  );

  static const String cloudinaryUploadPreset = String.fromEnvironment(
    'CLOUDINARY_UPLOAD_PRESET',
    defaultValue: 'paw_aid_cases', // Unsigned Upload Preset
  );

  static const String cloudinaryFolder = 'paw_aid_reports';

  /// Returns true if the user has configured their custom Cloudinary credentials
  static bool get isCloudinaryConfigured =>
      cloudinaryCloudName.isNotEmpty &&
      cloudinaryUploadPreset.isNotEmpty &&
      cloudinaryCloudName != 'YOUR_CLOUD_NAME' &&
      cloudinaryUploadPreset != 'YOUR_UPLOAD_PRESET';

  // ── Gemini 2.0 Flash Configuration (Option 3 Primary AI Triage) ─────────────
  // Free Developer Tier via Google AI Studio (https://aistudio.google.com)
  // Zero cloud billing, zero credit card, 15 RPM / 1,500 RPD free.
  static const String geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '', // Paste your free Google AI Studio key or pass via --dart-define
  );

  /// Returns true if Gemini API key is configured
  static bool get isGeminiConfigured =>
      geminiApiKey.isNotEmpty &&
      geminiApiKey != 'YOUR_GEMINI_API_KEY' &&
      geminiApiKey.startsWith('AIza');
}
