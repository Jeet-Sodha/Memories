import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/draft_media.dart';
import '../models/edit_media_entry.dart';
import '../models/memory.dart';
import '../models/memory_media.dart';
import '../utils/errors.dart';
import '../utils/media_utils.dart';
import 'storage_service.dart';

/// Talks to the `memories` and `memory_media` tables.
/// Row Level Security guarantees you only ever get YOUR rows; we also add
/// user_id filters as a second safety net.
class MemoryService {
  SupabaseClient get _client => Supabase.instance.client;
  final StorageService _storage = StorageService();

  static const _select = '*, memory_media(media_type)';

  String get _uid {
    final u = _client.auth.currentUser;
    if (u == null) throw AppException('Please log in again.');
    return u.id;
  }

  Future<List<Memory>> fetchMemories() async {
    final rows = await _client
        .from('memories')
        .select(_select)
        .eq('user_id', _uid);
    return rows.map<Memory>((r) => Memory.fromJson(r)).toList();
  }

  Future<List<MemoryMedia>> fetchMedia(String memoryId) async {
    final rows = await _client
        .from('memory_media')
        .select()
        .eq('memory_id', memoryId)
        .order('display_order', ascending: true);
    return rows.map<MemoryMedia>((r) => MemoryMedia.fromJson(r)).toList();
  }

  Future<List<Memory>> search(String query) async {
    final q = query.replaceAll(RegExp(r'[,()%*\\]'), ' ').trim();
    if (q.isEmpty) return [];
    final rows = await _client
        .from('memories')
        .select(_select)
        .eq('user_id', _uid)
        .or('title.ilike.%$q%,location_name.ilike.%$q%,description.ilike.%$q%');
    final list = rows.map<Memory>((r) => Memory.fromJson(r)).toList();
    list.sort((a, b) => b.displayDate.compareTo(a.displayDate));
    return list;
  }

  Future<void> setFavorite(String id, bool value) async {
    await _client.from('memories').update({'is_favorite': value}).eq('id', id);
  }

  Future<void> deleteMemory(Memory m) async {
    // Remove files first (best effort), then the row (media rows cascade).
    try {
      final media = await fetchMedia(m.id);
      await _storage.remove(
          SupabaseConfig.mediaBucket, media.map((e) => e.mediaPath).toList());
    } catch (_) {}
    await _client.from('memories').delete().eq('id', m.id);
  }

  /// Edit an existing memory: change text/location/date, remove some media,
  /// add new media. New files are uploaded FIRST, so if an upload fails the
  /// memory is left as it was.
  /// Saves edits. [ordered] is the FINAL story order (saved + new items);
  /// [removed] are saved items the user deleted.
  Future<Memory> updateMemory({
    required Memory original,
    required String title,
    String? description,
    String? locationName,
    required double latitude,
    required double longitude,
    required DateTime date,
    required List<EditMediaEntry> ordered,
    required List<MemoryMedia> removed,
    void Function(int done, int total, String label)? onProgress,
  }) async {
    final uid = _uid;
    final id = original.id;
    final newCount = ordered.where((e) => e.isNew).length;

    // 1) Upload + insert NEW media at the position the user chose.
    final uploaded = <String>[];
    final rows = <Map<String, dynamic>>[];
    try {
      var done = 0;
      for (var idx = 0; idx < ordered.length; idx++) {
        final entry = ordered[idx];
        if (!entry.isNew) continue;
        final item = entry.draft!;
        onProgress?.call(done, newCount, 'Uploading ${done + 1} of $newCount');

        var file = item.file;
        var ext = MediaUtils.extensionOf(file.path);
        if (item.kind == 'image') {
          file = await MediaUtils.compressImage(file);
          ext = MediaUtils.extensionOf(file.path);
        } else if (ext.isEmpty) {
          ext = item.kind == 'video' ? 'mp4' : 'm4a';
        }
        await MediaUtils.ensureUnderLimit(file);

        // unique name so it never overwrites an existing file
        final path =
            '$uid/$id/e${DateTime.now().microsecondsSinceEpoch}_$idx.$ext';
        await _storage.upload(
          bucket: SupabaseConfig.mediaBucket,
          path: path,
          file: file,
          contentType: MediaUtils.contentTypeFor(ext),
        );
        uploaded.add(path);
        rows.add({
          'memory_id': id,
          'media_type': item.kind,
          'media_url': path,
          'display_order': idx + 1,
        });
        done++;
      }
      if (rows.isNotEmpty) {
        await _client.from('memory_media').insert(rows);
      }
    } catch (e) {
      try {
        await _storage.remove(SupabaseConfig.mediaBucket, uploaded);
      } catch (_) {}
      rethrow;
    }

    // 2) Update the text / location / date.
    final desc = (description ?? '').trim();
    final locName = (locationName ?? '').trim();
    onProgress?.call(newCount, newCount, 'Saving…');
    await _client.from('memories').update({
      'title': title.trim(),
      'description': desc.isEmpty ? null : desc,
      'latitude': latitude,
      'longitude': longitude,
      'location_name': locName.isEmpty ? null : locName,
      'memory_date': date.toUtc().toIso8601String(),
    }).eq('id', id);

    // 3) Delete removed media (rows first, then files).
    for (final m in removed) {
      await _client.from('memory_media').delete().eq('id', m.id);
    }
    if (removed.isNotEmpty) {
      try {
        await _storage.remove(
            SupabaseConfig.mediaBucket, removed.map((m) => m.mediaPath).toList());
      } catch (_) {}
    }

    // 4) Save the new order of the items that already existed.
    for (var idx = 0; idx < ordered.length; idx++) {
      final saved = ordered[idx].saved;
      if (saved == null || saved.displayOrder == idx + 1) continue;
      final updated = await _client
          .from('memory_media')
          .update({'display_order': idx + 1})
          .eq('id', saved.id)
          .select();
      if (updated.isEmpty) {
        throw AppException(
            "Couldn't save the new order. Add an UPDATE policy for memory_media in Supabase (see README).");
      }
    }

    // 5) Cover = first image in the new order (or none).
    final after = await fetchMedia(id);
    String? cover;
    for (final m in after) {
      if (m.mediaType == 'image') {
        cover = m.mediaPath;
        break;
      }
    }
    await _client
        .from('memories')
        .update({'cover_image_url': cover}).eq('id', id);

    final full =
        await _client.from('memories').select(_select).eq('id', id).single();
    return Memory.fromJson(full);
  }

  /// Flow: insert memory -> upload each file -> insert memory_media rows
  /// -> set cover. If anything fails, everything is rolled back.
  Future<Memory> createMemory({
    required String title,
    String? description,
    String? locationName,
    required double latitude,
    required double longitude,
    required DateTime date,
    required List<DraftMedia> media,
    void Function(int done, int total, String label)? onProgress,
  }) async {
    final uid = _uid;
    final desc = (description ?? '').trim();
    final locName = (locationName ?? '').trim();

    final inserted = await _client
        .from('memories')
        .insert({
          'user_id': uid,
          'title': title.trim(),
          'description': desc.isEmpty ? null : desc,
          'latitude': latitude,
          'longitude': longitude,
          'location_name': locName.isEmpty ? null : locName,
          'memory_date': date.toUtc().toIso8601String(),
        })
        .select()
        .single();
    final memoryId = inserted['id'] as String;

    final uploaded = <String>[];
    try {
      final rows = <Map<String, dynamic>>[];
      String? cover;

      for (var i = 0; i < media.length; i++) {
        onProgress?.call(i, media.length, 'Uploading ${i + 1} of ${media.length}');
        final item = media[i];
        var file = item.file;
        var ext = MediaUtils.extensionOf(file.path);
        if (item.kind == 'image') {
          file = await MediaUtils.compressImage(file);
          ext = MediaUtils.extensionOf(file.path);
        } else if (ext.isEmpty) {
          ext = item.kind == 'video' ? 'mp4' : 'm4a';
        }
        await MediaUtils.ensureUnderLimit(file);

        // USER_ID / MEMORY_ID / 1.jpg
        final path = '$uid/$memoryId/${i + 1}.$ext';
        await _storage.upload(
          bucket: SupabaseConfig.mediaBucket,
          path: path,
          file: file,
          contentType: MediaUtils.contentTypeFor(ext),
        );
        uploaded.add(path);
        rows.add({
          'memory_id': memoryId,
          'media_type': item.kind,
          'media_url': path, // we store the PATH, not a public URL
          'display_order': i + 1,
        });
        if (cover == null && item.kind == 'image') cover = path;
      }

      onProgress?.call(media.length, media.length, 'Saving…');
      await _client.from('memory_media').insert(rows);
      if (cover != null) {
        await _client
            .from('memories')
            .update({'cover_image_url': cover}).eq('id', memoryId);
      }
      final full = await _client
          .from('memories')
          .select(_select)
          .eq('id', memoryId)
          .single();
      return Memory.fromJson(full);
    } catch (e) {
      try {
        await _storage.remove(SupabaseConfig.mediaBucket, uploaded);
      } catch (_) {}
      try {
        await _client.from('memories').delete().eq('id', memoryId);
      } catch (_) {}
      rethrow;
    }
  }
}
