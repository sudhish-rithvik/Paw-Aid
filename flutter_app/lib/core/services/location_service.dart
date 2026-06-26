// lib/core/services/location_service.dart
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Wrapper around geolocator for location services.
class LocationService {
  LocationService._();

  /// Request location permission. Returns true if granted.
  static Future<bool> requestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  /// Get the current device location. Returns null if unavailable.
  static Future<LatLng?> getCurrentLocation() async {
    final hasPermission = await requestPermission();
    if (!hasPermission) return null;

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      return LatLng(position.latitude, position.longitude);
    } catch (e) {
      // Fallback: try last known position
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) return LatLng(last.latitude, last.longitude);
      } catch (_) {}
      return null;
    }
  }

  /// Stream of position updates for live tracking.
  static Stream<Position> trackLocation() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // meters
      ),
    );
  }

  /// Returns the distance between two LatLng points in kilometers.
  static double distanceBetween(LatLng a, LatLng b) {
    final distanceInMeters = Geolocator.distanceBetween(
      a.latitude,
      a.longitude,
      b.latitude,
      b.longitude,
    );
    return distanceInMeters / 1000.0;
  }

  /// Open device app settings (for when permission is permanently denied).
  static Future<void> openAppSettings() async {
    await Geolocator.openAppSettings();
  }
}
