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
}
