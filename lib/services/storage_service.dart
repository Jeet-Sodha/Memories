import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class _SignedEntry {
  final String url;
  final DateTime expiresAt;
  _SignedEntry(this.url, this.expiresAt);
}

/// Buckets are PRIVATE, so we never use public URLs.
/// We ask Supabase for short-lived signed URLs and cache them in memory.
class StorageService {
  SupabaseClient get _client => Supabase.instance.client;

  static const int _expirySeconds = 3600;
  static final Map<String, _SignedEntry> _cache = {};
  static final Map<String, Future<String>> _pending = {};

  /// Returns an already-cached, still-valid URL immediately (or null).
  static String? peek(String bucket, String path) {
    final c = _cache['$bucket/$path'];
    if (c != null &&
        c.expiresAt.isAfter(DateTime.now().add(const Duration(minutes: 5)))) {
      return c.url;
    }
    return null;
  }

  Future<String> signedUrl(String bucket, String path) {
    final key = '$bucket/$path';
    final cached = _cache[key];
    if (cached != null &&
        cached.expiresAt.isAfter(DateTime.now().add(const Duration(minutes: 5)))) {
      return Future.value(cached.url);
    }
    return _pending[key] ??= _fetch(bucket, path, key);
  }

  Future<String> _fetch(String bucket, String path, String key) async {
    try {
      final url =
          await _client.storage.from(bucket).createSignedUrl(path, _expirySeconds);
      _cache[key] = _SignedEntry(
          url, DateTime.now().add(const Duration(seconds: _expirySeconds)));
      return url;
    } finally {
      _pending.remove(key);
    }
  }

  static void clearCache() {
    _cache.clear();
    _pending.clear();
  }

  Future<void> upload({
    required String bucket,
    required String path,
    required File file,
    required String contentType,
    bool upsert = false,
  }) async {
    await _client.storage.from(bucket).upload(
          path,
          file,
          fileOptions: FileOptions(contentType: contentType, upsert: upsert),
        );
  }

  Future<void> remove(String bucket, List<String> paths) async {
    if (paths.isEmpty) return;
    await _client.storage.from(bucket).remove(paths);
  }
}
