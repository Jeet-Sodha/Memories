import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../config/map_config.dart';
import '../services/location_service.dart';
import '../services/place_search_service.dart';
import '../state/memory_store.dart';
import '../theme/app_theme.dart';
import '../utils/errors.dart';
import '../widgets/app_states.dart';
import '../widgets/place_autocomplete_field.dart';

class PickedLocation {
  final double latitude;
  final double longitude;
  final String? name;
  const PickedLocation(this.latitude, this.longitude, this.name);
}

/// Pan the map so the pin sits on the place, or type a place name and pick
/// one of the suggestions.
class LocationPickerScreen extends StatefulWidget {
  final LatLng? initial;
  const LocationPickerScreen({super.key, this.initial});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final MapController _map = MapController();
  final LocationService _location = LocationService();
  final TextEditingController _search = TextEditingController();

  late LatLng _center;
  late final double _zoom;
  bool _busy = false;
  bool _mapReady = false;

  // Remember a suggestion the user picked, so we can reuse its name.
  String? _pickedName;
  LatLng? _pickedPoint;

  @override
  void initState() {
    super.initState();
    final latest = memoryStore.memories.isEmpty
        ? null
        : memoryStore.memories.first.latLng;
    _center = widget.initial ?? latest ?? const LatLng(20.0, 78.0);
    _zoom = widget.initial != null ? 14 : (latest != null ? 10 : 4);
  }

  @override
  void dispose() {
    _search.dispose();
    _map.dispose();
    super.dispose();
  }

  void _onPlace(PlaceResult r) {
    final p = LatLng(r.latitude, r.longitude);
    _pickedName = r.name;
    _pickedPoint = p;
    _center = p;
    if (_mapReady) _map.move(p, 14);
  }

  Future<void> _myLocation() async {
    setState(() => _busy = true);
    try {
      final pos = await _location.currentPosition();
      if (mounted && _mapReady) {
        _pickedName = null;
        _map.move(LatLng(pos.latitude, pos.longitude), 15);
      }
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm() async {
    setState(() => _busy = true);
    final c = _center;
    String? name;
    // Reuse the suggestion's name if the pin is still on that place.
    final pp = _pickedPoint;
    if (_pickedName != null &&
        pp != null &&
        (pp.latitude - c.latitude).abs() < 0.01 &&
        (pp.longitude - c.longitude).abs() < 0.01) {
      name = _pickedName;
    } else {
      name = await _location.placeName(c.latitude, c.longitude);
    }
    if (!mounted) return;
    Navigator.of(context).pop(PickedLocation(c.latitude, c.longitude, name));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: _zoom,
              minZoom: 2,
              maxZoom: 18,
              backgroundColor: AppColors.background,
              onMapReady: () => _mapReady = true,
              onPositionChanged: (camera, _) => _center = camera.center,
            ),
            children: [
              TileLayer(
                urlTemplate: MapConfig.tileUrl,
                userAgentPackageName: 'com.example.memories_app',
                retinaMode: RetinaMode.isHighDensity(context),
                panBuffer: 2,
                keepBuffer: 4,
                tileBuilder:
                    MapConfig.invertLightTiles ? MapConfig.invertBuilder : null,
              ),
              const RichAttributionWidget(
                showFlutterMapAttribution: false,
                alignment: AttributionAlignment.bottomLeft,
                attributions: [
                  TextSourceAttribution('© OpenStreetMap contributors © CARTO'),
                ],
              ),
            ],
          ),
          // Pin fixed at the center; its tip touches the exact point.
          IgnorePointer(
            child: Center(
              child: Transform.translate(
                offset: const Offset(0, -24),
                child: const Icon(Icons.location_on,
                    size: 48, color: AppColors.memory),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    style: IconButton.styleFrom(
                        backgroundColor: AppColors.surface),
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: PlaceAutocompleteField(
                      controller: _search,
                      hintText: 'Search a place (e.g. Nagpur)',
                      fillColor: AppColors.surface,
                      onSelected: _onPlace,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 110,
            child: FloatingActionButton.small(
              heroTag: 'pick-locate',
              backgroundColor: AppColors.surface,
              foregroundColor: AppColors.textPrimary,
              onPressed: _busy ? null : _myLocation,
              child: const Icon(Icons.my_location),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: SizedBox(
                  height: 56,
                  child: FilledButton(
                    onPressed: _busy ? null : _confirm,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accentLight,
                      foregroundColor: AppColors.onAccent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28)),
                    ),
                    child: _busy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: AppColors.onAccent))
                        : const Text('Use this location',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
