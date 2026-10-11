import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../utils/errors.dart';

/// One place suggestion (e.g. "Nagpur, Maharashtra, India").
class PlaceResult {
  final String name; // main text, e.g. "Nagpur"
  final String subtitle; // e.g. "Maharashtra, India"
  final double latitude;
  final double longitude;

  const PlaceResult({
    required this.name,
    required this.subtitle,
    required this.latitude,
    required this.longitude,
  });

  String get full => subtitle.isEmpty ? name : '$name, $subtitle';
}

/// Place search with live suggestions, using Photon (OpenStreetMap data).
/// Free, no API key, built for "search as you type". Please keep it
/// debounced (the UI does this) to be a good citizen.
class PlaceSearchService {
  static const String _host = 'photon.komoot.io';

  Future<List<PlaceResult>> search(String query) async {
    final q = query.trim();
    if (q.length < 2) return [];
    final data = await _getJson(Uri.https(_host, '/api/', {
      'q': q,
      'limit': '7',
      'lang': 'en',
    }));
    final features = (data is Map ? data['features'] : null);
    if (features is! List) return [];

    final out = <PlaceResult>[];
    final seen = <String>{};
    for (final f in features) {
      if (f is! Map) continue;
      final props = f['properties'];
      final geom = f['geometry'];
      if (props is! Map || geom is! Map) continue;
      final coords = geom['coordinates'];
      if (coords is! List || coords.length < 2) continue;

      final name = _s(props['name']).isNotEmpty
          ? _s(props['name'])
          : _s(props['street']);
      if (name.isEmpty) continue;

      final parts = <String>[];
      for (final key in ['city', 'town', 'village', 'county', 'state', 'country']) {
        final v = _s(props[key]);
        if (v.isNotEmpty && v != name && !parts.contains(v)) parts.add(v);
      }
      // Keep it short: at most 3 parts.
      final subtitle = parts.take(3).join(', ');

      final r = PlaceResult(
        name: name,
        subtitle: subtitle,
        latitude: (coords[1] as num).toDouble(),
        longitude: (coords[0] as num).toDouble(),
      );
      if (seen.add(r.full.toLowerCase())) out.add(r);
    }
    return out;
  }

  /// First (best) match for typed text, or null if nothing/offline.
  Future<PlaceResult?> best(String text) async {
    try {
      final r = await search(text);
      return r.isEmpty ? null : r.first;
    } catch (_) {
      return null;
    }
  }

  /// Best guess for the name of a coordinate (e.g. "Dharampeth, Nagpur").
  Future<String?> reverse(double lat, double lng) async {
    try {
      final data = await _getJson(Uri.https(_host, '/reverse', {
        'lat': '$lat',
        'lon': '$lng',
        'lang': 'en',
      }));
      final features = (data is Map ? data['features'] : null);
      if (features is! List || features.isEmpty) return null;
      final props = (features.first as Map)['properties'];
      if (props is! Map) return null;
      final parts = <String>[];
      for (final key in ['name', 'locality', 'district', 'city', 'town', 'village', 'state']) {
        final v = _s(props[key]);
        if (v.isNotEmpty && !parts.contains(v)) parts.add(v);
        if (parts.length == 2) break;
      }
      return parts.isEmpty ? null : parts.join(', ');
    } catch (_) {
      return null;
    }
  }

  static String _s(Object? v) => (v is String) ? v.trim() : '';

  Future<dynamic> _getJson(Uri uri) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 8);
    try {
      final req = await client.getUrl(uri).timeout(const Duration(seconds: 8));
      req.headers.set(HttpHeaders.userAgentHeader, 'MemoriesApp/1.0');
      req.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final res = await req.close().timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) {
        throw AppException('Place search is unavailable right now.');
      }
      final body = await res
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 10));
      return jsonDecode(body);
    } on SocketException {
      throw AppException('No internet connection.');
    } finally {
      client.close(force: true);
    }
  }
}
