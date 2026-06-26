// lib/core/services/api_service.dart
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide MultipartFile;

import '../constants/api_constants.dart';

/// Dio-based HTTP client with auth interceptor and error handling.
class ApiService {
  ApiService._();

  static Dio? _dio;

  static Dio get client {
    _dio ??= _buildDio();
    return _dio!;
  }

  static Dio _buildDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 60),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.add(_AuthInterceptor());
    dio.interceptors.add(_ErrorInterceptor());

    return dio;
  }

  // ─── Public reports ────────────────────────────────────────────────────────

  /// Submit a rescue report (multipart). Returns the created case map.
  static Future<Map<String, dynamic>> submitReport({
    required String imagePath,
    required double lat,
    required double lng,
    String? notes,
    String? userId,
  }) async {
    final formData = FormData.fromMap({
      'latitude': lat,
      'longitude': lng,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      if (userId != null) 'user_id': userId,
      'image': await MultipartFile.fromFile(
        imagePath,
        filename: 'animal_report.jpg',
      ),
    });
    final response = await client.post('/reports', data: formData);
    return response.data as Map<String, dynamic>;
  }

  /// Submit a rescue report using raw image bytes.
  static Future<Map<String, dynamic>> submitReportBytes({
    required List<int> imageBytes,
    required double lat,
    required double lng,
    String? notes,
    String? userId,
  }) async {
    final formData = FormData.fromMap({
      'latitude': lat,
      'longitude': lng,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      if (userId != null) 'user_id': userId,
      'image': MultipartFile.fromBytes(
        imageBytes,
        filename: 'animal_report.jpg',
        contentType: DioMediaType('image', 'jpeg'),
      ),
    });
    final response = await client.post('/reports', data: formData);
    return response.data as Map<String, dynamic>;
  }

  /// Get full case details and status.
  static Future<Map<String, dynamic>> getCaseStatus(String caseId) async {
    final response = await client.get('/cases/$caseId/status');
    return response.data as Map<String, dynamic>;
  }

  /// Get the full case detail.
  static Future<Map<String, dynamic>> getCaseDetail(String caseId) async {
    final response = await client.get('/cases/$caseId');
    return response.data as Map<String, dynamic>;
  }

  // ─── NGO operations ────────────────────────────────────────────────────────

  /// Get the rescue queue (sorted by AI recommendation score).
  static Future<List<dynamic>> getRescueQueue({String? ngoId}) async {
    final params = <String, dynamic>{};
    if (ngoId != null) params['ngo_id'] = ngoId;
    final response = await client.get('/ngo/queue', queryParameters: params);
    final data = response.data;
    if (data is List) return data;
    if (data is Map && data['cases'] is List) return data['cases'] as List;
    return [];
  }

  /// Accept a rescue case as an NGO.
  static Future<void> acceptCase(String caseId) async {
    await client.post('/ngo/cases/$caseId/accept');
  }

  /// Update the status of a case (with optional stage photo).
  static Future<void> updateCaseStatus(
    String caseId,
    String status, {
    List<int>? imageBytes,
    String? notes,
  }) async {
    if (imageBytes != null) {
      final formData = FormData.fromMap({
        'status': status,
        if (notes != null) 'notes': notes,
        'image': MultipartFile.fromBytes(
          imageBytes,
          filename: 'stage_update.jpg',
          contentType: DioMediaType('image', 'jpeg'),
        ),
      });
      await client.patch('/ngo/cases/$caseId/status', data: formData);
    } else {
      await client.patch('/ngo/cases/$caseId/status', data: {
        'status': status,
        if (notes != null) 'notes': notes,
      });
    }
  }

  /// Get cases near a location within a given radius.
  static Future<List<dynamic>> getNearbyCases({
    required double lat,
    required double lng,
    double radiusKm = 25,
  }) async {
    final response = await client.get('/cases/nearby', queryParameters: {
      'lat': lat,
      'lng': lng,
      'radius_km': radiusKm,
    });
    final data = response.data;
    if (data is List) return data;
    if (data is Map && data['cases'] is List) return data['cases'] as List;
    return [];
  }

  /// Get NGO-specific analytics.
  static Future<Map<String, dynamic>> getAnalytics({String? ngoId}) async {
    final params = <String, dynamic>{};
    if (ngoId != null) params['ngo_id'] = ngoId;
    final response =
        await client.get('/analytics', queryParameters: params.isEmpty ? null : params);
    return response.data as Map<String, dynamic>;
  }

  /// Get heatmap data points for the city-wide map.
  static Future<List<dynamic>> getHeatmapData() async {
    final response = await client.get('/analytics/heatmap');
    final data = response.data;
    if (data is List) return data;
    if (data is Map && data['points'] is List) return data['points'] as List;
    return [];
  }

  /// Get user's own reports.
  static Future<List<dynamic>> getMyReports() async {
    final response = await client.get('/citizen/reports');
    final data = response.data;
    if (data is List) return data;
    if (data is Map && data['cases'] is List) return data['cases'] as List;
    return [];
  }

  /// Get NGO profile.
  static Future<Map<String, dynamic>> getNGOProfile(String ngoId) async {
    final response = await client.get('/ngo/$ngoId/profile');
    return response.data as Map<String, dynamic>;
  }

  /// Register a new NGO (multipart with documents).
  static Future<Map<String, dynamic>> registerNGO(
    Map<String, dynamic> data,
    List<Map<String, dynamic>> documents,
  ) async {
    final formData = FormData.fromMap({...data});
    for (int i = 0; i < documents.length; i++) {
      final doc = documents[i];
      if (doc['bytes'] != null) {
        formData.files.add(MapEntry(
          'documents[$i]',
          MultipartFile.fromBytes(
            doc['bytes'] as List<int>,
            filename: doc['filename'] as String? ?? 'document_$i.pdf',
            contentType: DioMediaType('application', 'pdf'),
          ),
        ));
        formData.fields.add(MapEntry('document_types[$i]', doc['type'] as String? ?? 'other'));
      }
    }
    final response = await client.post('/ngo/register', data: formData);
    return response.data as Map<String, dynamic>;
  }

  // ─── Admin operations ──────────────────────────────────────────────────────

  /// Get list of NGOs pending approval.
  static Future<List<dynamic>> getPendingNGOs() async {
    final response = await client.get('/admin/ngos/pending');
    final data = response.data;
    if (data is List) return data;
    if (data is Map && data['ngos'] is List) return data['ngos'] as List;
    return [];
  }

  /// Approve an NGO.
  static Future<void> approveNGO(String ngoId) async {
    await client.post('/admin/ngos/$ngoId/approve');
  }

  /// Reject an NGO with a reason.
  static Future<void> rejectNGO(String ngoId, String reason) async {
    await client.post('/admin/ngos/$ngoId/reject', data: {'reason': reason});
  }

  /// Get platform-wide statistics for admin dashboard.
  static Future<Map<String, dynamic>> getPlatformStats() async {
    final response = await client.get('/admin/stats');
    return response.data as Map<String, dynamic>;
  }

  /// Get all cases for admin (paginated).
  static Future<Map<String, dynamic>> getAllCases({
    int page = 1,
    int pageSize = 20,
    String? search,
    String? status,
    String? severity,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'page_size': pageSize,
      if (search != null && search.isNotEmpty) 'search': search,
      if (status != null) 'status': status,
      if (severity != null) 'severity': severity,
    };
    final response = await client.get('/admin/cases', queryParameters: params);
    return response.data as Map<String, dynamic>;
  }

  /// Get NGO detail for admin verification.
  static Future<Map<String, dynamic>> getNGODetail(String ngoId) async {
    final response = await client.get('/admin/ngos/$ngoId');
    return response.data as Map<String, dynamic>;
  }

  // ─── Routing ───────────────────────────────────────────────────────────────

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
          .map((c) => [(c as List)[1] as double, c[0] as double])
          .toList();
    } catch (e) {
      return [];
    }
  }
}

// ─── Interceptors ─────────────────────────────────────────────────────────────

class _AuthInterceptor extends Interceptor {
  @override
  void onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      options.headers['Authorization'] = 'Bearer ${session.accessToken}';
    }
    handler.next(options);
  }
}

class _ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    String message = _humanReadableError(err);
    handler.next(
      DioException(
        requestOptions: err.requestOptions,
        response: err.response,
        type: err.type,
        error: message,
        message: message,
      ),
    );
  }

  String _humanReadableError(DioException err) {
    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.sendTimeout) {
      return 'Connection timed out. Please check your network and try again.';
    }
    if (err.type == DioExceptionType.connectionError) {
      return 'Cannot reach the server. Please check your internet connection.';
    }
    final statusCode = err.response?.statusCode;
    if (statusCode != null) {
      final responseData = err.response?.data;
      String? serverMsg;
      if (responseData is Map) {
        serverMsg = responseData['detail']?.toString() ??
            responseData['message']?.toString() ??
            responseData['error']?.toString();
      }
      if (serverMsg != null && serverMsg.isNotEmpty) return serverMsg;
      switch (statusCode) {
        case 400:
          return 'Bad request. Please check your input.';
        case 401:
          return 'Authentication required. Please sign in.';
        case 403:
          return 'You do not have permission for this action.';
        case 404:
          return 'Resource not found.';
        case 422:
          return 'Invalid data. Please check your input.';
        case 429:
          return 'Too many requests. Please wait a moment.';
        case 500:
          return 'Server error. Please try again later.';
        default:
          return 'Request failed (HTTP $statusCode).';
      }
    }
    return 'An unexpected error occurred. Please try again.';
  }
}
