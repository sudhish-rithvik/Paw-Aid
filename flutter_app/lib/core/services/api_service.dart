// lib/core/services/api_service.dart
import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import 'report_service.dart';
import 'ngo_service.dart';
import 'rescue_service.dart';
import 'admin_service.dart';

/// PAW AID Application API Facade
/// Central coordinator routing operations across citizen, NGO, and admin services.
class ApiService {
  ApiService._();

  // ─── Citizen Reports ───────────────────────────────────────────────────────

  /// Submit an animal rescue report
  static Future<Map<String, dynamic>> submitReport({
    required String imagePath,
    required double lat,
    required double lng,
    String? address,
    String animalType = 'Dog',
    String? notes,
    String? userId,
  }) async {
    return ReportService.submitAnimalReport(
      imageSource: imagePath,
      latitude: lat,
      longitude: lng,
      address: address,
      animalType: animalType,
      notes: notes,
      userId: userId,
    );
  }

  /// Submit a rescue report using raw image bytes
  static Future<Map<String, dynamic>> submitReportBytes({
    required List<int> imageBytes,
    required double lat,
    required double lng,
    String? address,
    String animalType = 'Dog',
    String? notes,
    String? userId,
  }) async {
    return ReportService.submitAnimalReport(
      imageSource: imageBytes,
      latitude: lat,
      longitude: lng,
      address: address,
      animalType: animalType,
      notes: notes,
      userId: userId,
    );
  }

  /// Get authoritative case status and details
  static Future<Map<String, dynamic>> getCaseStatus(String caseId) async {
    return ReportService.getReport(caseId);
  }

  /// Get the full case detail
  static Future<Map<String, dynamic>> getCaseDetail(String caseId) async {
    return ReportService.getReport(caseId);
  }

  /// Get citizen's own submitted rescue reports
  static Future<List<dynamic>> getMyReports() async {
    return ReportService.getMyReports();
  }

  // ─── NGO Operations ────────────────────────────────────────────────────────

  /// Get the rescue queue (Status: AWAITING_NGO / Pending)
  static Future<List<dynamic>> getRescueQueue({String? ngoId}) async {
    return NgoService.getRescueQueue(ngoId: ngoId);
  }

  /// Accept a rescue case as an NGO
  static Future<void> acceptCase(String caseId) async {
    await RescueService.acceptRescueReport(caseId);
  }

  /// Update the status of a case (7-stage workflow) with optional evidence photo
  static Future<void> updateCaseStatus(
    String caseId,
    String status, {
    List<int>? imageBytes,
    String? notes,
  }) async {
    await RescueService.updateRescueStatus(
      caseId,
      status,
      imageBytes: imageBytes,
      notes: notes,
    );
  }

  /// Get cases near a location within a given radius
  static Future<List<dynamic>> getNearbyCases({
    required double lat,
    required double lng,
    double radiusKm = 25,
  }) async {
    return NgoService.getNearbyCases(lat: lat, lng: lng, radiusKm: radiusKm);
  }

  /// Get NGO-specific analytics
  static Future<Map<String, dynamic>> getAnalytics({String? ngoId}) async {
    return NgoService.getAnalytics(ngoId: ngoId);
  }

  /// Get NGO profile
  static Future<Map<String, dynamic>> getNGOProfile(String ngoId) async {
    return NgoService.getNGOProfile(ngoId);
  }

  /// Register a new NGO
  static Future<Map<String, dynamic>> registerNGO(
    Map<String, dynamic> data,
    List<Map<String, dynamic>> documents,
  ) async {
    return NgoService.registerNGO(data, documents);
  }

  // ─── Admin Operations ──────────────────────────────────────────────────────

  /// Get list of NGOs pending verification
  static Future<List<dynamic>> getPendingNGOs() async {
    return AdminService.getPendingNGOs();
  }

  /// Approve an NGO
  static Future<void> approveNGO(String ngoId) async {
    await AdminService.approveNGO(ngoId);
  }

  /// Reject an NGO with audit reason
  static Future<void> rejectNGO(String ngoId, String reason) async {
    await AdminService.rejectNGO(ngoId, reason);
  }

  /// Get platform-wide statistics for admin dashboard
  static Future<Map<String, dynamic>> getPlatformStats() async {
    return AdminService.getPlatformStats();
  }

  /// Get all cases for admin (paginated)
  static Future<Map<String, dynamic>> getAllCases({
    int page = 1,
    int pageSize = 20,
    String? search,
    String? status,
    String? severity,
  }) async {
    return AdminService.getAllReports(
      page: page,
      pageSize: pageSize,
      search: search,
      status: status,
      severity: severity,
    );
  }

  /// Get NGO detail for admin verification
  static Future<Map<String, dynamic>> getNGODetail(String ngoId) async {
    return AdminService.getNGODetail(ngoId);
  }

  /// Get heatmap data points for the city-wide map
  static Future<List<dynamic>> getHeatmapData() async {
    final reports = await NgoService.getRescueQueue();
    return reports.map((r) => {
          'lat': (r['latitude'] ?? r['lat'] as num?)?.toDouble() ?? 13.0827,
          'lng': (r['longitude'] ?? r['lng'] as num?)?.toDouble() ?? 80.2707,
          'weight': r['priority_level'] == 'critical' ? 1.0 : (r['priority_level'] == 'high' ? 0.75 : 0.5),
        }).toList();
  }

  // ─── Routing & OpenStreetMap ───────────────────────────────────────────────

  /// Get OSRM route between two coordinates. Returns list of [lat, lng] pairs.
  static Future<List<List<double>>> getRoute({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) async {
    try {
      final url =
          '${ApiConstants.osrmBaseUrl}/$fromLng,$fromLat;$toLng,$toLat?overview=full&geometries=geojson';
      final response = await Dio().get(url);
      final data = response.data as Map<String, dynamic>;
      final routes = data['routes'] as List?;
      if (routes == null || routes.isEmpty) return [];
      final coords = (routes[0] as Map)['geometry']['coordinates'] as List;
      return coords
          .map((c) => [(c[1] as num).toDouble(), (c[0] as num).toDouble()])
          .toList();
    } catch (_) {
      return [];
    }
  }
}
