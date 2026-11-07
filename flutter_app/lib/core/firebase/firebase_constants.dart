// lib/core/firebase/firebase_constants.dart

/// Firebase & Cloud Firestore Collection Names & Spark Constraints
class FirebaseConstants {
  FirebaseConstants._();

  // ─── Firestore Top-Level Collections ───────────────────────────────────────
  static const String colUsers = 'users';
  static const String colReports = 'reports';
  static const String colRescueCases = 'rescue_cases'; // Legacy alias maintained for backwards compatibility
  static const String colNgos = 'ngos';
  static const String colAssignments = 'assignments';
  static const String colNotifications = 'notifications';
  static const String colStatusHistory = 'status_history';
  static const String colVolunteers = 'volunteers';

  // ─── Firestore Subcollections ──────────────────────────────────────────────
  static const String subcolStatusHistory = 'status_history';
  static const String subcolEvents = 'events';
  static const String subcolComments = 'comments';

  // ─── User Roles ────────────────────────────────────────────────────────────
  static const String roleCitizen = 'citizen';
  static const String roleNgo = 'ngo_staff';
  static const String roleAdmin = 'admin';

  // ─── Spark Plan Constraints & Protections ──────────────────────────────────
  /// Default query page size for paginated queries to protect the 50,000 reads/day Spark limit.
  static const int defaultPageSize = 20;

  /// Maximum photo payload size (150 KB) permitted under Spark 1 MiB document ceiling
  static const int maxCompressedImageSizeBytes = 150 * 1024;

  /// Default Firestore cache size (100 MB).
  /// Keeps reads within the 50,000/day free Spark limit through aggressive client-side caching.
  static const int firestoreCacheSizeBytes = 100 * 1024 * 1024;
}
