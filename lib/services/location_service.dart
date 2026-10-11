import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../utils/errors.dart';
import 'place_search_service.dart';

/// Location permission is requested only when the user taps a
/// "use my location" button, never on app launch.
class LocationService {
  Future<Position> currentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw AppException(
          'Location services are turned off. Turn them on in Settings.');
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied) {
      throw AppException(
          'Location permission was denied. You can still pick a place on the map.');
    }
    if (perm == LocationPermission.deniedForever) {
      throw AppException(
          'Location permission is blocked. Enable it in Settings > Memories.');
    }
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );
  }

  /// "Colaba, Mumbai" style name, or null if it can't be found.
  Future<String?> placeName(double lat, double lng) async {
    // 1) The phone's own geocoder (fast, offline-ish).
    try {
      final marks = await placemarkFromCoordinates(lat, lng);
      if (marks.isNotEmpty) {
        final m = marks.first;
        String clean(String? s) => (s ?? '').trim();
        var parts = [clean(m.subLocality), clean(m.locality)]
            .where((s) => s.isNotEmpty)
            .toList();
        if (parts.isEmpty) {
          parts = [clean(m.administrativeArea), clean(m.country)]
              .where((s) => s.isNotEmpty)
              .toList();
        }
        if (parts.isNotEmpty) return parts.join(', ');
      }
    } catch (_) {}
    // 2) Fallback: online lookup (works on phones without a geocoder).
    return PlaceSearchService().reverse(lat, lng);
  }

  /// Search a place by name ("Lonavala") and return its coordinates.
  Future<LatLng?> searchPlace(String query) async {
    try {
      final r = await PlaceSearchService().search(query);
      if (r.isEmpty) return null;
      return LatLng(r.first.latitude, r.first.longitude);
    } catch (_) {
      return null;
    }
  }

  Future<void> openSettings() => Geolocator.openAppSettings();
}
