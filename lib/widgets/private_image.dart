import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../config/supabase_config.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

/// Shows an image stored in a PRIVATE bucket (signed URL + disk cache).
///
/// FIX: when the path changes (or Flutter re-uses this widget for a different
/// marker), the old URL is thrown away immediately, so one memory's photo can
/// never appear on another memory's bubble.
class PrivateImage extends StatefulWidget {
  final String? path;
  final String bucket;
  final BoxFit fit;
  final int? cacheWidth;
  final Widget? fallback;

  const PrivateImage({
    super.key,
    required this.path,
    this.bucket = SupabaseConfig.mediaBucket,
    this.fit = BoxFit.cover,
    this.cacheWidth,
    this.fallback,
  });

  @override
  State<PrivateImage> createState() => _PrivateImageState();
}

class _PrivateImageState extends State<PrivateImage> {
  String? _url;
  String? _resolvedFor; // "bucket/path" that _url belongs to

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant PrivateImage old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path || old.bucket != widget.bucket) _resolve();
  }

  void _resolve() {
    final p = widget.path;
    final b = widget.bucket;
    _url = null; // never keep a previous image's URL
    if (p == null || p.isEmpty) {
      _resolvedFor = null;
      return;
    }
    final key = '$b/$p';
    _resolvedFor = key;

    final cached = StorageService.peek(b, p);
    if (cached != null) {
      _url = cached;
      return;
    }
    StorageService().signedUrl(b, p).then((url) {
      if (!mounted || _resolvedFor != key) return; // widget moved on
      setState(() => _url = url);
    }).catchError((_) {});
  }

  Widget get _placeholder =>
      widget.fallback ??
      Container(
        color: AppColors.elevated,
        alignment: Alignment.center,
        child: const Icon(Icons.image_outlined,
            color: Color(0x669296A3), size: 32),
      );

  @override
  Widget build(BuildContext context) {
    final url = _url;
    if (url == null) return _placeholder;
    return CachedNetworkImage(
      key: ValueKey('${widget.bucket}/${widget.path}'),
      imageUrl: url,
      cacheKey: '${widget.bucket}/${widget.path}',
      fit: widget.fit,
      width: double.infinity,
      height: double.infinity,
      memCacheWidth: widget.cacheWidth,
      fadeInDuration: const Duration(milliseconds: 220),
      placeholder: (_, __) => _placeholder,
      errorWidget: (_, __, ___) => _placeholder,
    );
  }
}
