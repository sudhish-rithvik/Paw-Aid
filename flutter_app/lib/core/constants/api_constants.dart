// lib/core/constants/api_constants.dart

class ApiConstants {
  // Map tiles (OpenStreetMap — 100% Free)
  static const String osmTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String osmAttribution = '© OpenStreetMap contributors';

  // OSRM routing
  static const String osrmBaseUrl = 'http://router.project-osrm.org/route/v1/driving';

  // Nominatim reverse geocoding
  static const String nominatimUrl = 'https://nominatim.openstreetmap.org/reverse';

  ApiConstants._();
}

enum CaseStatus {
  pending,
  accepted,
  dispatched,
  animalPicked,
  vetTreatment,
  recovery,
  completed,
  closed;

  String get displayName => switch (this) {
        pending => 'Pending',
        accepted => 'NGO Accepted',
        dispatched => 'Team Dispatched',
        animalPicked => 'Animal Picked Up',
        vetTreatment => 'Vet Treatment',
        recovery => 'Recovery',
        completed => 'Completed',
        closed => 'Closed',
      };

  String get emoji => switch (this) {
        pending => '⏳',
        accepted => '✅',
        dispatched => '🚗',
        animalPicked => '🐾',
        vetTreatment => '🏥',
        recovery => '💊',
        completed => '❤️',
        closed => '🔒',
      };

  static CaseStatus fromString(String s) {
    final normalized = s.replaceAll('_', '').toLowerCase();
    return CaseStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == normalized || e.name.toLowerCase() == s.toLowerCase(),
      orElse: () => CaseStatus.pending,
    );
  }
}

enum PriorityLevel { critical, high, medium, low }

// ignore: constant_identifier_names
enum UserRole { citizen, ngo_staff, admin }
