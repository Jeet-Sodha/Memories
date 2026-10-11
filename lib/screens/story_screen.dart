import 'dart:async';
import 'dart:ui';
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../config/supabase_config.dart';
import '../models/memory.dart';
import '../models/memory_media.dart';
import '../services/memory_service.dart';
import '../services/storage_service.dart';
import '../state/memory_store.dart';
import '../theme/app_theme.dart';
import '../utils/errors.dart';
import '../utils/format.dart';
import '../widgets/private_image.dart';
import '../widgets/story_progress.dart';

/// Opens the full-screen story with a soft fade.
Future<void> openStory(BuildContext context, Memory memory) {
  return Navigator.of(context).push(PageRouteBuilder<void>(
    opaque: true,
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (_, __, ___) => StoryScreen(memory: memory),
    transitionsBuilder: (_, anim, __, child) =>
        FadeTransition(opacity: anim, child: child),
  ));
}

/// Full-screen story: media played in memory_media.display_order.
/// Tap right = next, tap left = previous, hold = pause.
class StoryScreen extends StatefulWidget {
  final Memory memory;
  const StoryScreen({super.key, required this.memory});

  @override
  State<StoryScreen> createState() => _StoryScreenState();
}

class _StoryScreenState extends State<StoryScreen>
    with SingleTickerProviderStateMixin {
  final MemoryService _memoryService = MemoryService();
  final StorageService _storage = StorageService();

  late final AnimationController _progress;

  List<MemoryMedia> _items = [];
  bool _loadingList = true;
  String? _listError;

  int _index = 0;
  int _token = 0; // ignores results from items we've already skipped
  bool _mediaLoading = true;
  bool _itemFailed = false;
  bool _paused = false;
  bool _closing = false;
  bool _timerDriven = false; // images use a timer; video/audio use playback
  String? _url;

  VideoPlayerController? _video;
  AudioPlayer? _audio;
  Duration? _audioDuration;
  Duration _audioPosition = Duration.zero;
  final List<StreamSubscription<dynamic>> _subs = [];

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    _progress = AnimationController(
        vsync: this, duration: const Duration(seconds: 5))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed && _timerDriven && !_paused) {
          _next();
        }
      });
    _loadItems();
  }

  @override
  void dispose() {
    _progress.dispose();
    for (final s in _subs) {
      s.cancel();
    }
    _video?.removeListener(_onVideoTick);
    _video?.dispose();
    _audio?.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    try {
      final items = await _memoryService.fetchMedia(widget.memory.id);
      items.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
      if (!mounted) return;
      if (items.isEmpty) {
        setState(() {
          _loadingList = false;
          _listError = 'This memory has no media yet.';
        });
        return;
      }
      setState(() {
        _items = items;
        _loadingList = false;
      });
      await _show(0);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingList = false;
        _listError = friendlyError(e);
      });
    }
  }

  Future<void> _show(int i) async {
    final token = ++_token;
    _progress.stop();
    _progress.value = 0;
    _timerDriven = false;

    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    final oldVideo = _video;
    final oldAudio = _audio;
    oldVideo?.removeListener(_onVideoTick);

    setState(() {
      _index = i;
      _mediaLoading = true;
      _itemFailed = false;
      _url = null;
      _video = null;
      _audio = null;
      _audioDuration = null;
      _audioPosition = Duration.zero;
    });
    // Dispose after the frame so nothing draws a disposed controller.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      oldVideo?.dispose();
      oldAudio?.dispose();
    });

    final item = _items[i];
    try {
      final url =
          await _storage.signedUrl(SupabaseConfig.mediaBucket, item.mediaPath);
      if (!mounted || token != _token) return;
      switch (item.mediaType) {
        case 'video':
          await _startVideo(url, token);
          break;
        case 'audio':
          await _startAudio(url, token);
          break;
        default:
          await _startImage(url, item.mediaPath, token);
      }
    } catch (_) {
      if (!mounted || token != _token) return;
      setState(() {
        _mediaLoading = false;
        _itemFailed = true;
      });
    }
  }

  Future<void> _startImage(String url, String path, int token) async {
    try {
      await precacheImage(
          CachedNetworkImageProvider(url,
              cacheKey: '${SupabaseConfig.mediaBucket}/$path'),
          context);
    } catch (_) {}
    if (!mounted || token != _token) return;
    setState(() {
      _url = url;
      _mediaLoading = false;
    });
    _timerDriven = true;
    _progress.duration = const Duration(seconds: 5);
    if (!_paused) _progress.forward(from: 0);
  }

  Future<void> _startVideo(String url, int token) async {
    final c = VideoPlayerController.networkUrl(Uri.parse(url));
    try {
      await c.initialize();
    } catch (_) {
      await c.dispose();
      rethrow;
    }
    if (!mounted || token != _token) {
      await c.dispose();
      return;
    }
    c.addListener(_onVideoTick);
    setState(() {
      _video = c;
      _url = url;
      _mediaLoading = false;
    });
    if (!_paused) await c.play();
  }

  void _onVideoTick() {
    final v = _video;
    if (v == null || !v.value.isInitialized) return;
    final total = v.value.duration.inMilliseconds;
    if (total <= 0) return;
    final pos = v.value.position.inMilliseconds;
    _progress.value = (pos / total).clamp(0.0, 1.0).toDouble();
    if (pos >= total - 120 && !v.value.isPlaying && !_paused) _next();
  }

  Future<void> _startAudio(String url, int token) async {
    final p = AudioPlayer();
    await p.setSource(UrlSource(url));
    final dur = await p.getDuration();
    if (!mounted || token != _token) {
      await p.dispose();
      return;
    }
    _audio = p;
    _audioDuration = dur;
    _subs.add(p.onPositionChanged.listen((pos) {
      final total = _audioDuration?.inMilliseconds ?? 0;
      if (total > 0) {
        _progress.value = (pos.inMilliseconds / total).clamp(0.0, 1.0).toDouble();
      }
      if (mounted) setState(() => _audioPosition = pos);
    }));
    _subs.add(p.onPlayerComplete.listen((_) {
      if (!_paused) _next();
    }));
    setState(() {
      _url = url;
      _mediaLoading = false;
    });
    if (!_paused) await p.resume();
  }

  void _pause() {
    _paused = true;
    _progress.stop();
    _video?.pause();
    _audio?.pause();
  }

  void _resume() {
    _paused = false;
    if (_mediaLoading || _itemFailed) return;
    if (_timerDriven) _progress.forward();
    _video?.play();
    _audio?.resume();
  }

  void _next() {
    if (_closing) return;
    if (_index < _items.length - 1) {
      _show(_index + 1);
    } else {
      _close();
    }
  }

  void _prev() => _show(_index > 0 ? _index - 1 : 0);

  void _close() {
    if (_closing) return;
    _closing = true;
    Navigator.of(context).maybePop();
  }

  Future<void> _toggleFavorite() async {
    final current = memoryStore.byId(widget.memory.id) ?? widget.memory;
    final ok = await memoryStore.toggleFavorite(current);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update favorite.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _loadingList
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accentLight))
          : _listError != null
              ? _buildError()
              : _buildStory(),
    );
  }

  Widget _buildError() {
    return SafeArea(
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topRight,
            child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: _close),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(_listError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStory() {
    final memory = memoryStore.byId(widget.memory.id) ?? widget.memory;
    final desc = (memory.description ?? '').trim();
    final width = MediaQuery.of(context).size.width;

    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) => d.globalPosition.dx < width * 0.33 ? _prev() : _next(),
          onLongPressStart: (_) => _pause(),
          onLongPressEnd: (_) => _resume(),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            child: KeyedSubtree(
              key: ValueKey('story_${_index}_$_mediaLoading'),
              child: _buildMedia(),
            ),
          ),
        ),

        // Gradients so text stays readable on any photo.
        IgnorePointer(
          child: Column(
            children: [
              Container(
                height: 170,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xB3000000), Color(0x00000000)],
                  ),
                ),
              ),
              const Spacer(),
              Container(
                height: 280,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), Color(0xE6000000)],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Top: progress bars + controls
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 0),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: StoryProgress(
                      count: _items.length,
                      currentIndex: _index,
                      progress: _progress,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Spacer(),
                      ListenableBuilder(
                        listenable: memoryStore,
                        builder: (_, __) {
                          final fav =
                              (memoryStore.byId(widget.memory.id) ?? widget.memory)
                                  .isFavorite;
                          return IconButton(
                            onPressed: _toggleFavorite,
                            icon: Icon(
                                fav ? Icons.favorite : Icons.favorite_border,
                                color: fav ? AppColors.memory : Colors.white),
                          );
                        },
                      ),
                      IconButton(
                        onPressed: _close,
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        // Bottom: location, date, caption
        Positioned(
          left: 22,
          right: 22,
          bottom: 0,
          child: IgnorePointer(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.place,
                            size: 18, color: AppColors.location),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            memory.locationName ?? 'Unnamed place',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(formatDateLong(memory.displayDate),
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xCCFFFFFF))),
                    const SizedBox(height: 12),
                    Text(memory.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            height: 1.2)),
                    if (desc.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('"$desc"',
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 15,
                              fontStyle: FontStyle.italic,
                              height: 1.4,
                              color: Color(0xE6FFFFFF))),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMedia() {
    if (_itemFailed) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.broken_image_outlined,
                  size: 48, color: AppColors.textSecondary),
              SizedBox(height: 12),
              Text("Couldn't load this item.\nTap to continue.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary)),
            ],
          ),
        ),
      );
    }
    if (_mediaLoading || _url == null) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.accentLight));
    }
    final item = _items[_index];
    switch (item.mediaType) {
      case 'video':
        final c = _video;
        if (c == null) return const SizedBox.shrink();
        return Center(
          child: AspectRatio(
              aspectRatio: c.value.aspectRatio, child: VideoPlayer(c)),
        );
      case 'audio':
        return _buildAudio();
      default:
        final key = '${SupabaseConfig.mediaBucket}/${item.mediaPath}';
        return Stack(
          fit: StackFit.expand,
          children: [
            ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: CachedNetworkImage(
                  imageUrl: _url!,
                  cacheKey: key,
                  fit: BoxFit.cover,
                  memCacheWidth: 500),
            ),
            CachedNetworkImage(
              imageUrl: _url!,
              cacheKey: key,
              fit: BoxFit.contain,
              memCacheWidth: 1600,
              fadeInDuration: const Duration(milliseconds: 150),
              errorWidget: (_, __, ___) => const Center(
                  child: Icon(Icons.broken_image_outlined,
                      size: 48, color: AppColors.textSecondary)),
            ),
          ],
        );
    }
  }

  Widget _buildAudio() {
    return Stack(
      fit: StackFit.expand,
      children: [
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
          child: PrivateImage(
              path: widget.memory.coverImagePath, cacheWidth: 400),
        ),
        Container(color: const Color(0xB3090B12)),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 132,
                height: 132,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.card,
                  border: Border.all(color: AppColors.accent, width: 2),
                  boxShadow: const [
                    BoxShadow(color: Color(0x668B91E8), blurRadius: 40)
                  ],
                ),
                child: const Icon(Icons.mic,
                    size: 56, color: AppColors.accentLight),
              ),
              const SizedBox(height: 22),
              const Text('Voice memory',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(
                '${formatDuration(_audioPosition)} / ${formatDuration(_audioDuration ?? Duration.zero)}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
