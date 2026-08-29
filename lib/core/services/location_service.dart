import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class LocationService {
  // Preset Coordinates for Key Informal Market Hubs in Ghana
  static const LatLng accraCenter = LatLng(5.5586, -0.2014); // Circle VIP / Kwame Nkrumah Overpass
  static const LatLng kumasiCenter = LatLng(6.6961, -1.6234); // Kejetia Market Complex
  static const LatLng temaCenter = LatLng(5.6424, 0.0050); // Community 1 Main Market

  /// Calculates the distance between two coordinates in kilometers.
  static double calculateDistanceKm({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) {
    try {
      final distanceInMeters = Geolocator.distanceBetween(
        startLatitude,
        startLongitude,
        endLatitude,
        endLongitude,
      );
      return distanceInMeters / 1000.0;
    } catch (_) {
      return 0.0;
    }
  }

  /// Formats distance in km or m for UI display (e.g. '1.2 km away').
  static String formatDistance(double distanceKm) {
    if (distanceKm <= 0) return '';
    if (distanceKm < 1.0) {
      final meters = (distanceKm * 1000).round();
      return '$meters m away';
    }
    return '${distanceKm.toStringAsFixed(1)} km away';
  }

  /// Get center coordinates for a Ghana city.
  static LatLng getCityCoordinates(String city) {
    switch (city.toLowerCase()) {
      case 'kumasi':
        return kumasiCenter;
      case 'tema':
        return temaCenter;
      case 'accra':
      default:
        return accraCenter;
    }
  }
}
