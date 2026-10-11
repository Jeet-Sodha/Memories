import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../config/map_config.dart';
import '../models/memory.dart';
import '../services/location_service.dart';
import '../state/memory_store.dart';
import '../theme/app_theme.dart';
import '../utils/errors.dart';
import '../widgets/app_logo.dart';
import '../widgets/app_states.dart';
import '../widgets/cluster_sheet.dart';
import '../widgets/memory_marker_layer.dart';
import '../widgets/memory_preview_card.dart';
import 'memory_detail_screen.dart';
import 'search_screen.dart';
import 'story_screen.dart';

/// HOME: dark map with circular photo memories.
class ExploreScreen extends StatefulWidget {
  final VoidCallback onCreateTap;
  const ExploreScreen({super.key, required this.onCreateTap});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen>
    with SingleTickerProviderStateMixin {
  final MapController _map = MapController();
  final LocationService _location = LocationService();

  bool _mapReady = false;
  bool _didInitialFit = false;
  bool _locating = false;
  Memory? _selected;
  LatLng? _myLocation;
  double _rotation = 0; // map rotation in degrees (0 = north up)

  // ---- animated camera ("fly to") ----
  late final AnimationController _camAnim;
  // Start/end positions in "world pixels at zoom 0" (lets us pan smoothly).
  math.Point<double> _fromP = const math.Point<double>(0, 0);
  math.Point<double> _toP = const math.Point<double>(0, 0);
  double _fromZ = 0, _toZ = 0, _fromR = 0, _toR = 0;
  bool _animRot = false;
  bool _mapBuilt = false; // the map is created once memories have loaded

  @override
  void initState() {
    super.initState();
    _camAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..addListener(_onCamTick)
      ..addStatusListener((st) {
        if (st == AnimationStatus.completed && _mapReady) {
          _syncRotation(_map.camera.rotation);
        }
      });
    memoryStore.addListener(_onStore);
  }

  @override
  void dispose() {
    memoryStore.removeListener(_onStore);
    _camAnim.dispose();
    _map.dispose();
    super.dispose();
  }

  double _normDeg(double d) {
    var r = d % 360;
    if (r > 180) r -= 360;
    if (r < -180) r += 360;
    return r;
  }

  /// Keeps the compass arrow in sync with the REAL map rotation.
  /// (Programmatic rotations don't always trigger onPositionChanged, so we
  /// also call this from every map event and from the animation itself.)
  void _syncRotation(double raw) {
    if (!mounted) return;
    final r = _normDeg(raw);
    if ((r - _rotation).abs() < 0.3) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks) {
      // We are in the middle of building; update right after this frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _rotation = r);
      });
      WidgetsBinding.instance.scheduleFrame();
    } else {
      setState(() => _rotation = r);
    }
  }

  void _onCamTick() {
    if (!_mapReady) return;
    final e = Curves.easeInOutCubic.transform(_camAnim.value);
    final zoom = _fromZ + (_toZ - _fromZ) * e;

    // While zooming, pan so the target travels in a straight line ON SCREEN.
    // This is what makes the zoom feel smooth instead of "swooping".
    var s = e;
    if ((_toZ - _fromZ).abs() > 0.01) {
      final a = math.pow(2, -_fromZ).toDouble();
      final b = math.pow(2, -_toZ).toDouble();
      final c = math.pow(2, -zoom).toDouble();
      s = ((c - a) / (b - a)).clamp(0.0, 1.0).toDouble();
    }
    final cam = _map.camera;
    final p = math.Point<double>(
      _fromP.x + (_toP.x - _fromP.x) * s,
      _fromP.y + (_toP.y - _fromP.y) * s,
    );
    final center = cam.unproject(p, 0);
    final rot = _animRot ? _fromR + (_toR - _fromR) * e : cam.rotation;

    // ONE camera update per frame (move + rotate together).
    _map.moveAndRotate(center, zoom, rot);
    _syncRotation(_map.camera.rotation);
  }

  /// Smoothly moves/zooms/rotates the map.
  /// [yOffsetPx] shifts the target up so it isn't hidden behind the bottom card.
  void _flyTo({
    LatLng? center,
    double? zoom,
    double? rotation,
    int? ms,
    double yOffsetPx = 0,
  }) {
    if (!_mapReady) return;
    final cam = _map.camera;
    _fromZ = cam.zoom;
    _toZ = (zoom ?? cam.zoom).clamp(2.0, 18.0).toDouble();

    var target = center ?? cam.center;
    if (yOffsetPx != 0) {
      final tp = cam.project(target, _toZ);
      target = cam.unproject(math.Point<double>(tp.x, tp.y + yOffsetPx), _toZ);
    }
    _fromP = cam.project(cam.center, 0);
    _toP = cam.project(target, 0);

    _animRot = rotation != null;
    _fromR = _normDeg(cam.rotation);
    _toR = rotation ?? _fromR;

    // Bigger trips / zoom changes get a little more time.
    final dz = (_toZ - _fromZ).abs();
    final dx = _toP.x - _fromP.x;
    final dy = _toP.y - _fromP.y;
    final worldFraction = math.sqrt(dx * dx + dy * dy) / 256.0;
    final dur = (650 + dz * 110 + worldFraction * 500).clamp(650.0, 1500.0);
    _camAnim.duration = Duration(milliseconds: (ms ?? dur).round());
    _camAnim.forward(from: 0);
  }

  void _resetNorth() {
    HapticFeedback.selectionClick();
    _flyTo(rotation: 0, ms: 500);
  }

  void _onStore() {
    if (!mounted) return;
    final focus = memoryStore.takeFocus();
    if (focus != null) {
      _select(focus);
      return;
    }
    if (_selected != null) {
      final updated = memoryStore.byId(_selected!.id);
      setState(() => _selected = updated); // null if it was deleted
    }
    _fitOnce();
  }

  void _fitOnce() {
    if (!_mapReady || _didInitialFit || memoryStore.memories.isEmpty) return;
    _didInitialFit = true;
    final points = memoryStore.memories.map((m) => m.latLng).toList();
    _map.fitCamera(CameraFit.bounds(
      bounds: LatLngBounds.fromPoints(points),
      padding: const EdgeInsets.fromLTRB(70, 170, 70, 260),
      maxZoom: 13,
    ));
  }

  void _select(Memory m) {
    HapticFeedback.selectionClick();
    setState(() => _selected = m);
    if (_mapReady) {
      // Smooth zoom-in onto the tapped bubble.
      _flyTo(
          center: m.latLng,
          zoom: math.max(_map.camera.zoom, 14.5),
          yOffsetPx: 90);
    }
  }

  void _onClusterTap(List<Memory> group) {
    final first = group.first;
    final allSame = group.every((m) =>
        (m.latitude - first.latitude).abs() < 0.0002 &&
        (m.longitude - first.longitude).abs() < 0.0002);
    if (!allSame && _map.camera.zoom < 16) {
      // Smoothly zoom so every memory in this bubble fits on screen.
      final fit = CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(group.map((m) => m.latLng).toList()),
        padding: const EdgeInsets.all(90),
        maxZoom: 17,
      ).fit(_map.camera);
      _flyTo(center: fit.center, zoom: fit.zoom);
      return;
    }
    final names = group
        .map((m) => (m.locationName ?? '').trim())
        .where((n) => n.isNotEmpty)
        .toList();
    final place = names.isEmpty ? null : names.first;
    ClusterSheet.show(
      context,
      memories: group,
      onSelect: _select,
      onViewAll: place == null
          ? null
          : () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => SearchScreen(initialQuery: place))),
    );
  }

  Future<void> _locate() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      final pos = await _location.currentPosition();
      final here = LatLng(pos.latitude, pos.longitude);
      if (!mounted) return;
      setState(() => _myLocation = here);
      _flyTo(center: here, zoom: 15);
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Widget _buildMap(BuildContext context, List<Memory> memories) {
    // Frame all memories straight away, so the map never starts on the
    // whole world and then zooms in (that was the loading delay).
    final CameraFit? initialFit = memories.isEmpty
        ? null
        : CameraFit.bounds(
            bounds:
                LatLngBounds.fromPoints(memories.map((m) => m.latLng).toList()),
            padding: const EdgeInsets.fromLTRB(70, 170, 70, 260),
            maxZoom: 13,
          );
    return FlutterMap(
      mapController: _map,
      options: MapOptions(
        initialCenter: const LatLng(20.0, 78.0),
        initialZoom: 4,
        initialCameraFit: initialFit,
        minZoom: 2,
        maxZoom: 18,
        backgroundColor: AppColors.background,
        onMapReady: () {
          _mapReady = true;
          final focus = memoryStore.takeFocus();
          if (focus != null) {
            _select(focus);
          } else {
            _fitOnce();
          }
        },
        onPositionChanged: (camera, hasGesture) {
          if (!_mapReady || !mounted) return;
          // Touching the map cancels any running animation.
          if (hasGesture && _camAnim.isAnimating) _camAnim.stop();
          _syncRotation(camera.rotation);
        },
        onMapEvent: (event) {
          if (_mapReady) _syncRotation(event.camera.rotation);
        },
        onTap: (_, __) {
          if (_selected != null) setState(() => _selected = null);
        },
      ),
      children: [
        TileLayer(
          urlTemplate: MapConfig.tileUrl,
          userAgentPackageName: 'com.example.memories_app',
          // Sharp labels on high-density phone screens (@2x tiles).
          retinaMode: RetinaMode.isHighDensity(context),
          // Load a bit beyond the screen so panning feels instant.
          panBuffer: 2,
          keepBuffer: 4,
          tileBuilder:
              MapConfig.invertLightTiles ? MapConfig.invertBuilder : null,
        ),
        MemoryMarkerLayer(
          memories: memories,
          selectedId: _selected?.id,
          onMemoryTap: _select,
          onClusterTap: _onClusterTap,
        ),
        if (_myLocation != null)
          MarkerLayer(markers: [
            Marker(
              point: _myLocation!,
              width: 28,
              height: 28,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.accentLight,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: const [
                    BoxShadow(color: Color(0x888B91E8), blurRadius: 12)
                  ],
                ),
              ),
            ),
          ]),
        const RichAttributionWidget(
          showFlutterMapAttribution: false,
          alignment: AttributionAlignment.bottomLeft,
          attributions: [
            TextSourceAttribution('© OpenStreetMap contributors © CARTO'),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    return ListenableBuilder(
      listenable: memoryStore,
      builder: (context, _) {
        final memories = memoryStore.memories;
        final empty = memories.isEmpty && memoryStore.loadedOnce;
        // Build the map only once we know where the memories are.
        if (!_mapBuilt &&
            (memoryStore.loadedOnce || memoryStore.error != null)) {
          _mapBuilt = true;
          _didInitialFit = memories.isNotEmpty; // initialCameraFit handles it
        }
        final hasSelection = _selected != null;
        final showCompass = _rotation.abs() > 1;

        return Stack(
          children: [
            if (_mapBuilt) _buildMap(context, memories) else const _MapLoading(),

            // Soft top fade + title
            IgnorePointer(
              child: Container(
                height: 190,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xF2090B12), Color(0x00090B12)],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 22,
              right: 80,
              child: IgnorePointer(
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Your Memory Map',
                            style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.8)),
                        const SizedBox(height: 4),
                        Text(
                          memoryStore.loading && memories.isEmpty
                              ? 'Loading your memories…'
                              : '${memories.length} memor${memories.length == 1 ? 'y' : 'ies'} across ${memoryStore.placeCount} place${memoryStore.placeCount == 1 ? '' : 's'}',
                          style: const TextStyle(
                              fontSize: 15, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Compass (appears when the map is rotated; tap = north up)
            Positioned(
              top: topInset + 14,
              right: 16,
              child: IgnorePointer(
                ignoring: !showCompass,
                child: AnimatedScale(
                  scale: showCompass ? 1 : 0,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutBack,
                  child: AnimatedOpacity(
                    opacity: showCompass ? 1 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: _MapButton(
                      onTap: _resetNorth,
                      child: Transform.rotate(
                        angle: _rotation * math.pi / 180,
                        child: const Icon(Icons.navigation,
                            color: AppColors.memory, size: 26),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Search + locate buttons
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              right: 16,
              bottom: hasSelection ? 232 : (empty ? 250 : 28),
              child: Column(
                children: [
                  _MapButton(
                    icon: Icons.search,
                    onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SearchScreen())),
                  ),
                  const SizedBox(height: 12),
                  _MapButton(
                      icon: Icons.my_location,
                      loading: _locating,
                      onTap: _locate),
                ],
              ),
            ),

            if (memoryStore.loading && memories.isEmpty)
              const Center(
                child: CircularProgressIndicator(color: AppColors.accentLight),
              ),

            // Bottom area: preview / empty / error
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                transitionBuilder: (child, anim) => SlideTransition(
                  position: Tween<Offset>(
                          begin: const Offset(0, 0.25), end: Offset.zero)
                      .animate(CurvedAnimation(
                          parent: anim, curve: Curves.easeOutCubic)),
                  child: FadeTransition(opacity: anim, child: child),
                ),
                child: _selected != null
                    ? MemoryPreviewCard(
                        key: ValueKey(_selected!.id),
                        memory: _selected!,
                        onClose: () => setState(() => _selected = null),
                        onViewStory: () => openStory(context, _selected!),
                        onOpenDetails: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) =>
                                  MemoryDetailScreen(memory: _selected!)),
                        ),
                      )
                    : (memoryStore.error != null && memories.isEmpty)
                        ? _FloatingCard(
                            key: const ValueKey('error'),
                            child: ErrorView(
                                message: memoryStore.error!,
                                onRetry: memoryStore.load),
                          )
                        : empty
                            ? _FloatingCard(
                                key: const ValueKey('empty'),
                                child: EmptyMemoriesView(
                                    compact: true,
                                    onCreate: widget.onCreateTap),
                              )
                            : (memoryStore.error != null
                                ? GestureDetector(
                                    key: const ValueKey('refresh-error'),
                                    onTap: memoryStore.load,
                                    child: _FloatingCard(
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.refresh,
                                              size: 18,
                                              color: AppColors.accentLight),
                                          const SizedBox(width: 8),
                                          Flexible(
                                              child: Text(
                                                  '${memoryStore.error} Tap to retry.',
                                                  style: const TextStyle(
                                                      fontSize: 13))),
                                        ],
                                      ),
                                    ),
                                  )
                                : const SizedBox.shrink(key: ValueKey('none'))),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Shown for a moment while memories load, before the map is created.
class _MapLoading extends StatelessWidget {
  const _MapLoading();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      alignment: Alignment.center,
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppLogo(size: 84, pulse: true),
          SizedBox(height: 18),
          Text('Loading your map…',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
        ],
      ),
    );
  }
}

class _FloatingCard extends StatelessWidget {
  final Widget child;
  const _FloatingCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xF21C2230),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.line),
      ),
      child: child,
    );
  }
}

class _MapButton extends StatelessWidget {
  final IconData? icon;
  final Widget? child;
  final VoidCallback onTap;
  final bool loading;
  const _MapButton(
      {this.icon, this.child, required this.onTap, this.loading = false});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xE6151923),
      shape: const CircleBorder(side: BorderSide(color: AppColors.line)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 52,
          height: 52,
          child: loading
              ? const Padding(
                  padding: EdgeInsets.all(15),
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: AppColors.accentLight))
              : (child ?? Icon(icon, color: AppColors.textPrimary)),
        ),
      ),
    );
  }
}
