import 'dart:io';
import 'dart:math' as math;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/profile.dart';
import '../utils/errors.dart';
import '../utils/media_utils.dart';
import 'storage_service.dart';

class ProfileService {
  SupabaseClient get _client => Supabase.instance.client;
  final StorageService _storage = StorageService();

  String get _uid {
    final u = _client.auth.currentUser;
    if (u == null) throw AppException('Please log in again.');
    return u.id;
  }

  /// Permanently deletes the signed-in user and everything they own.
  /// Needs the `delete_my_account` SQL function (see README).
  Future<void> deleteAccount() async {
    final uid = _uid;

    // 0) Make sure the server function exists BEFORE removing any files.
    try {
      await _client.rpc('delete_my_account', params: {'dry_run': true});
    } on PostgrestException catch (e) {
      final m = e.message.toLowerCase();
      if (e.code == 'PGRST202' ||
          e.code == '42883' ||
          m.contains('could not find the function') ||
          m.contains('does not exist')) {
        throw AppException(
            "Account deletion isn't set up on the server yet. The app owner must run the delete_my_account SQL (see README).");
      }
      rethrow;
    }

    // 1) Remove all uploaded files (best effort).
    try {
      final rows = await _client.from('memory_media').select('media_url');
      final paths = rows.map<String>((r) => r['media_url'] as String).toList();
      for (var i = 0; i < paths.length; i += 100) {
        await _storage.remove(SupabaseConfig.mediaBucket,
            paths.sublist(i, math.min(i + 100, paths.length)));
      }
    } catch (_) {}
    try {
      final p = await fetchProfile();
      final a = p?.avatarPath;
      if (a != null && a.isNotEmpty) {
        await _storage.remove(SupabaseConfig.avatarBucket, [a]);
      }
    } catch (_) {}

    // 2) Delete the user. The database cascades to profile, memories and media.
    await _client.rpc('delete_my_account');

    // 3) Clear the local session and caches.
    StorageService.clearCache();
    try {
      await _client.auth.signOut(scope: SignOutScope.local);
    } catch (_) {}
    // `uid` is only used to prove we're signed in above.
    assert(uid.isNotEmpty);
  }

  Future<Profile?> fetchProfile() async {
    final row =
        await _client.from('profiles').select().eq('id', _uid).maybeSingle();
    return row == null ? null : Profile.fromJson(row);
  }

  Future<void> updateDisplayName(String name) async {
    final n = name.trim();
    if (n.isEmpty) throw AppException('Name cannot be empty.');
    await _client.from('profiles').update({'display_name': n}).eq('id', _uid);
  }

  /// Uploads to avatars/USER_ID/avatar_<time>.jpg and returns the path.
  Future<String> uploadAvatar(File picked, {String? oldPath}) async {
    final compressed = await MediaUtils.compressImage(picked);
    final path = '$_uid/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await _storage.upload(
      bucket: SupabaseConfig.avatarBucket,
      path: path,
      file: compressed,
      contentType: 'image/jpeg',
    );
    await _client.from('profiles').update({'avatar_url': path}).eq('id', _uid);
    if (oldPath != null && oldPath.isNotEmpty) {
      try {
        await _storage.remove(SupabaseConfig.avatarBucket, [oldPath]);
      } catch (_) {}
    }
    return path;
  }
}
