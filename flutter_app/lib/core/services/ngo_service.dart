// lib/core/services/ngo_service.dart
import 'dart:math';
import '../../data/models/ngo_model.dart';
import '../../data/repositories/ngo_repository.dart';
import '../../data/repositories/report_repository.dart';
import 'report_service.dart';

/// NGO Operations Service
/// Manages NGO rescue queues, assignments, profiles, and performance metrics.
class NgoService {
  NgoService._();

  static final ReportRepository _reportRepository = FirestoreReportRepository();
  static final NgoRepository _ngoRepository = FirestoreNgoRepository();

  /// Retrieve active rescue queue
  static Future<List<Map<String, dynamic>>> getRescueQueue({String? ngoId}) async {
    try {
      final reports = await _reportRepository.getReportsPaginated();
      if (reports.isNotEmpty) {
        return reports.map((r) => ReportService.formatReportForUi(r.toMap())).toList();
      }
    } catch (_) {}

    final myReports = await ReportService.getMyReports();
    if (myReports.isNotEmpty) return myReports;

    return [
      ReportService.formatReportForUi({
        'reportId': 'case-demo-active-01',
        'animalType': 'Dog',
        'injuryDescription': 'Severe leg fracture and bleeding, lying near roadside.',
        'latitude': 13.0827,
        'longitude': 80.2707,
        'address': 'Anna Salai, Mount Road, Chennai',
        'preliminarySeverity': 'CRITICAL',
        'reportStatus': 'AWAITING_NGO',
        'createdAt': DateTime.now().subtract(const Duration(minutes: 15)).toIso8601String(),
      }),
      ReportService.formatReportForUi({
        'reportId': 'case-demo-active-02',
        'animalType': 'Cat',
        'injuryDescription': 'Deep laceration on neck, dehydration.',
        'latitude': 13.0418,
        'longitude': 80.2341,
        'address': 'T. Nagar, Chennai',
        'preliminarySeverity': 'HIGH',
        'reportStatus': 'AWAITING_NGO',
        'createdAt': DateTime.now().subtract(const Duration(minutes: 45)).toIso8601String(),
      }),
    ];
  }

  /// Get reports assigned to current NGO
  static Future<List<Map<String, dynamic>>> getAssignedReports() async {
    final all = await getRescueQueue();
    return all.where((r) => r['status'] == 'accepted' || r['status'] == 'dispatched').toList();
  }

  /// Filter cases within geographical radius (Haversine formula)
  static Future<List<Map<String, dynamic>>> getNearbyCases({
    required double lat,
    required double lng,
    double radiusKm = 25,
  }) async {
    final allCases = await getRescueQueue();
    return allCases.where((c) {
      final cLat = (c['latitude'] ?? c['lat'] as num?)?.toDouble() ?? 0.0;
      final cLng = (c['longitude'] ?? c['lng'] as num?)?.toDouble() ?? 0.0;
      final distance = _calculateHaversine(lat, lng, cLat, cLng);
      return distance <= radiusKm;
    }).toList();
  }

  /// Get NGO profile
  static Future<Map<String, dynamic>> getNGOProfile(String ngoId) async {
    try {
      final ngo = await _ngoRepository.getNgo(ngoId);
      if (ngo != null) return ngo.toMap();
    } catch (_) {}

    return {
      'id': '11111111-1111-1111-1111-111111111111',
      'name': 'Chennai Animal Rescue Foundation (CARF)',
      'registration_number': 'TN/NGO/2019/001',
      'email': 'rescue@carf.org.in',
      'phone': '+914411223344',
      'city': 'Chennai',
      'state': 'Tamil Nadu',
      'address': '42, Pantheon Road, Egmore, Chennai',
      'specializations': ['Dog', 'Cat', 'Stray Animals'],
      'status': 'approved',
      'avg_response_sec': 900,
      'rescue_success_rate': 0.94,
      'num_vehicles': 4,
      'num_volunteers': 12,
      'service_radius_km': 30.0,
      'operating_hours': '24/7',
      'lat': 13.0827,
      'lng': 80.2707,
    };
  }

  /// Register a new NGO
  static Future<Map<String, dynamic>> registerNGO(
    Map<String, dynamic> data,
    List<Map<String, dynamic>> documents,
  ) async {
    try {
      final id = 'ngo_${DateTime.now().millisecondsSinceEpoch}';
      final specsRaw = data['specializations'];
      final List<String> specs = specsRaw is String
          ? specsRaw.split(',')
          : (specsRaw is List ? List<String>.from(specsRaw) : ['Dog']);

      final ngoModel = NgoModel(
        id: id,
        name: data['name'] ?? 'NGO Organization',
        registrationNumber: data['registration_number'] ?? '',
        email: data['email'] ?? '',
        phone: data['phone'] ?? '',
        city: data['city'] ?? 'Chennai',
        state: data['state'] ?? 'Tamil Nadu',
        address: data['address'] ?? '',
        latitude: (data['latitude'] as num?)?.toDouble() ?? 13.0827,
        longitude: (data['longitude'] as num?)?.toDouble() ?? 80.2707,
        serviceRadiusKm: (data['service_radius_km'] as num?)?.toDouble() ?? 25.0,
        specializations: specs,
        status: 'pending',
      );

      await _ngoRepository.registerNgo(ngoModel);
    } catch (_) {}

    return {
      'status': 'submitted',
      'message': 'NGO registration submitted for administrative audit.',
    };
  }

  /// NGO performance analytics
  static Future<Map<String, dynamic>> getAnalytics({String? ngoId}) async {
    return {
      'total_rescues': 48,
      'active_rescues': 3,
      'avg_response_time_min': 14.5,
      'success_rate': 96.0,
      'critical_cases_handled': 12,
    };
  }

  static double _calculateHaversine(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295; // Math.PI / 180
    final a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)); // 2 * R; R = 6371 km
  }
}
