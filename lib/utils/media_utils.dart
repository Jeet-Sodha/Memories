import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/draft_media.dart';
import 'errors.dart';

/// Validation + compression for selected media.
/// We validate by file extension (more reliable than MIME on phones).
class MediaUtils {
  static const int maxBytes = 50 * 1024 * 1024; // Supabase Free plan limit

  static const imageExt = {'jpg', 'jpeg', 'png', 'webp', 'heic', 'heif'};
  static const videoExt = {'mp4', 'mov'};
  static const audioExt = {'mp3', 'wav', 'm4a'};

  static String extensionOf(String path) =>
      p.extension(path).replaceFirst('.', '').toLowerCase();

  static String? kindOf(String path) {
    final e = extensionOf(path);
    if (imageExt.contains(e)) return 'image';
    if (videoExt.contains(e)) return 'video';
    if (audioExt.contains(e)) return 'audio';
    return null;
  }

  static String contentTypeFor(String ext) {
    switch (ext.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      case 'm4a':
        return 'audio/mp4';
      default:
        throw AppException('That file type is not supported.');
    }
  }

  /// Validates a picked file and wraps it as a [DraftMedia].
  /// [assumed] is used when the picker returns a path without an extension.
  static Future<DraftMedia> draftFrom(String path, {String? assumed}) async {
    final kind = kindOf(path) ?? assumed;
    if (kind == null) {
      throw AppException(
          'Unsupported file. Use JPG/PNG/WebP photos, MP4/MOV videos or MP3/WAV/M4A audio.');
    }
    final file = File(path);
    if (!await file.exists()) throw AppException('Could not read that file.');
    final size = await file.length();
    // Photos get compressed later, so only check videos/audio here.
    if (kind != 'image' && size > maxBytes) {
      final mb = (size / 1024 / 1024).toStringAsFixed(0);
      throw AppException(
          'That file is $mb MB. The upload limit is 50 MB. Try a shorter clip.');
    }
    return DraftMedia(
      id: '${DateTime.now().microsecondsSinceEpoch}_${p.basename(path)}',
      file: file,
      kind: kind,
    );
  }

  /// Shrinks a photo to max ~1600px JPEG. Also converts HEIC/PNG.
  static Future<File> compressImage(File input) async {
    try {
      final dir = await getTemporaryDirectory();
      final target = p.join(
          dir.path, 'cmp_${DateTime.now().microsecondsSinceEpoch}.jpg');
      final out = await FlutterImageCompress.compressAndGetFile(
        input.path,
        target,
        quality: 80,
        minWidth: 1600,
        minHeight: 1600,
        format: CompressFormat.jpeg,
      );
      if (out != null) return File(out.path);
    } catch (_) {}
    // Fallback: use the original if it is already an allowed web format.
    final ext = extensionOf(input.path);
    if (const {'jpg', 'jpeg', 'png', 'webp'}.contains(ext)) return input;
    throw AppException('Could not process one of your photos.');
  }

  static Future<void> ensureUnderLimit(File f) async {
    if (await f.length() > maxBytes) {
      throw AppException('A file is larger than the 50 MB upload limit.');
    }
  }
}
