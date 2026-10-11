import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../models/draft_media.dart';
import '../services/location_service.dart';
import '../services/memory_service.dart';
import '../services/place_search_service.dart';
import '../state/memory_store.dart';
import '../theme/app_theme.dart';
import '../utils/errors.dart';
import '../utils/format.dart';
import '../utils/media_utils.dart';
import '../widgets/app_states.dart';
import '../widgets/animations.dart';
import '../widgets/media_add_sheet.dart';
import '../widgets/place_autocomplete_field.dart';
import 'location_picker_screen.dart';

/// "Capture a moment": media + title + description + location + date.
class CreateMemoryScreen extends StatefulWidget {
  final VoidCallback onCreated;
  const CreateMemoryScreen({super.key, required this.onCreated});

  @override
  State<CreateMemoryScreen> createState() => _CreateMemoryScreenState();
}

class _CreateMemoryScreenState extends State<CreateMemoryScreen> {
  final _service = MemoryService();
  final _locationService = LocationService();

  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _locName = TextEditingController();

  final List<DraftMedia> _media = [];
  double? _lat;
  double? _lng;
  DateTime _date = DateTime.now();

  bool _saving = false;
  bool _locating = false;
  String? _pickedName; // name that matches the current pin
  bool _locEdited = false; // user typed in the name box after pinning
  double _progress = 0;
  String _progressLabel = '';
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _locName.dispose();
    super.dispose();
  }

  // ---------- media ----------

  Future<void> _addPaths(List<String> paths, {String? assumed}) async {
    String? firstError;
    for (final path in paths) {
      try {
        final d = await MediaUtils.draftFrom(path, assumed: assumed);
        if (mounted) setState(() => _media.add(d));
      } catch (e) {
        firstError ??= friendlyError(e);
      }
    }
    if (firstError != null && mounted) showSnack(context, firstError);
  }

  /// Camera / photo library / video / voice (shared with the edit screen).
  void _showAddSheet() {
    showAddMediaSheet(
      context,
      onPaths: (paths, kind) => _addPaths(paths, assumed: kind),
    );
  }

  // ---------- location & date ----------

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    try {
      final pos = await _locationService.currentPosition();
      final name =
          await _locationService.placeName(pos.latitude, pos.longitude);
      if (!mounted) return;
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
        if (name != null) _locName.text = name;
        _pickedName = _locName.text.trim();
        _locEdited = false;
      });
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _pickOnMap() async {
    final result = await Navigator.of(context).push<PickedLocation>(
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
            initial: (_lat != null && _lng != null)
                ? LatLng(_lat!, _lng!)
                : null),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _lat = result.latitude;
      _lng = result.longitude;
      if (result.name != null) _locName.text = result.name!;
      _pickedName = _locName.text.trim();
      _locEdited = false;
    });
  }

  /// The user tapped a suggestion while typing (e.g. "Nagpur").
  void _onPlaceSelected(PlaceResult r) {
    setState(() {
      _lat = r.latitude;
      _lng = r.longitude;
      _pickedName = r.name;
      _locEdited = false;
      _error = null;
    });
  }

  /// If the user typed a place but never tapped a suggestion, look it up now.
  Future<void> _resolveTypedLocation() async {
    final text = _locName.text.trim();
    final needs = text.length >= 2 &&
        (_lat == null || (_locEdited && text != _pickedName));
    if (!needs) return;
    final hit = await PlaceSearchService().best(text);
    if (hit != null && mounted) {
      setState(() {
        _lat = hit.latitude;
        _lng = hit.longitude;
        _pickedName = text;
        _locEdited = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1950),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (d != null) setState(() => _date = d);
  }

  // ---------- save ----------

  String? _validate() {
    if (_media.isEmpty) return 'Add at least one photo, video or voice note.';
    if (_title.text.trim().isEmpty) return 'Give your memory a title.';
    if (_title.text.trim().length > 150) {
      return 'Title must be 150 characters or fewer.';
    }
    if (_desc.text.length > 5000) {
      return 'Description must be 5000 characters or fewer.';
    }
    if (_lat == null || _lng == null) {
      return "We couldn't find that place. Pick a suggestion, use your current location, or choose it on the map.";
    }
    return null;
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
      _progress = 0;
      _progressLabel = 'Checking the place…';
    });
    await _resolveTypedLocation();
    final problem = _validate();
    if (problem != null) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = problem;
        });
      }
      return;
    }
    if (mounted) setState(() => _progressLabel = 'Preparing…');
    try {
      final created = await _service.createMemory(
        title: _title.text,
        description: _desc.text,
        locationName: _locName.text,
        latitude: _lat!,
        longitude: _lng!,
        date: DateTime(_date.year, _date.month, _date.day, 12),
        media: List.of(_media),
        onProgress: (done, total, label) {
          if (!mounted) return;
          setState(() {
            _progress = total == 0 ? 0 : done / total;
            _progressLabel = label;
          });
        },
      );
      memoryStore.addCreated(created);
      if (!mounted) return;
      _reset();
      showSnack(context, 'Memory saved.');
      widget.onCreated(); // jump to the map
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _reset() {
    setState(() {
      _media.clear();
      _title.clear();
      _desc.clear();
      _locName.clear();
      _pickedName = null;
      _locEdited = false;
      _lat = null;
      _lng = null;
      _date = DateTime.now();
      _error = null;
    });
  }

  // ---------- UI ----------

  Widget _mediaTile(int index) {
    final d = _media[index];
    Widget content;
    if (d.kind == 'image') {
      content = Image.file(d.file,
          fit: BoxFit.cover,
          cacheWidth: 360,
          errorBuilder: (_, __, ___) => const Center(
              child: Icon(Icons.image_outlined,
                  color: AppColors.textSecondary)));
    } else {
      content = Container(
        color: AppColors.elevated,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(d.kind == 'video' ? Icons.videocam : Icons.mic,
                size: 32, color: AppColors.accentLight),
            const SizedBox(height: 6),
            Text(d.kind == 'video' ? 'Video' : 'Voice',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
      );
    }
    return Padding(
      key: ValueKey(d.id),
      padding: const EdgeInsets.only(right: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          width: 108,
          child: Stack(
            fit: StackFit.expand,
            children: [
              content,
              Positioned(
                top: 6,
                left: 6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: const Color(0xB3090B12),
                      borderRadius: BorderRadius.circular(10)),
                  child: Text('${index + 1}',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ),
              Positioned(
                top: 2,
                right: 2,
                child: IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: _saving
                      ? null
                      : () => setState(() => _media.removeAt(index)),
                  icon: const Icon(Icons.cancel,
                      size: 22, color: Color(0xE6FFFFFF)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasLocation = _lat != null && _lng != null;
    return SafeArea(
      bottom: false,
      child: AbsorbPointer(
        absorbing: _saving,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
          children: [
            const Text('Capture a moment',
                style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.8)),
            const SizedBox(height: 4),
            const Text('Anchor a memory to the map.',
                style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 18),

            // Media area
            if (_media.isEmpty)
              GestureDetector(
                onTap: _showAddSheet,
                child: Container(
                  height: 180,
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate_outlined,
                          size: 38, color: AppColors.accentLight),
                      SizedBox(height: 10),
                      Text('Tap to add photos, videos or voice',
                          style: TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              )
            else ...[
              SizedBox(
                height: 150,
                child: ReorderableListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _media.length,
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (newIndex > oldIndex) newIndex -= 1;
                      final item = _media.removeAt(oldIndex);
                      _media.insert(newIndex, item);
                    });
                  },
                  itemBuilder: (_, i) => _mediaTile(i),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                        'Story order = this order. Long-press & drag to reorder.',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ),
                  TextButton.icon(
                    onPressed: _showAddSheet,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add'),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),

            TextField(
              controller: _title,
              maxLength: 150,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Title'),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _desc,
              maxLength: 5000,
              minLines: 4,
              maxLines: 8,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                  hintText: 'What do you want to remember about this place?'),
            ),
            const SizedBox(height: 8),

            // Location card
            FadeSlideIn(
              index: 2,
              child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.place,
                          color: hasLocation
                              ? AppColors.location
                              : AppColors.textSecondary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          hasLocation
                              ? 'Pin set  ·  ${_lat!.toStringAsFixed(4)}, ${_lng!.toStringAsFixed(4)}'
                              : 'Type a place below, or use the buttons',
                          style: const TextStyle(
                              fontSize: 14, color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  PlaceAutocompleteField(
                    controller: _locName,
                    hintText: 'Search a place (e.g. Nagpur)',
                    fillColor: AppColors.elevated,
                    onSelected: _onPlaceSelected,
                    onEdited: (_) => _locEdited = true,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _locating ? null : _useCurrentLocation,
                          icon: _locating
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2))
                              : const Icon(Icons.my_location, size: 18),
                          label: const Text('Current'),
                          style: _outlined,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickOnMap,
                          icon: const Icon(Icons.map_outlined, size: 18),
                          label: const Text('Pick on map'),
                          style: _outlined,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )),
            const SizedBox(height: 12),

            // Date
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.line),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        color: AppColors.memory),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text(formatDateLong(_date),
                            style: const TextStyle(fontSize: 15))),
                    const Icon(Icons.edit_outlined,
                        size: 18, color: AppColors.textSecondary),
                  ],
                ),
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.error)),
            ],
            const SizedBox(height: 20),

            if (_saving) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _progress == 0 ? null : _progress,
                  minHeight: 6,
                  backgroundColor: AppColors.elevated,
                  color: AppColors.accentLight,
                ),
              ),
              const SizedBox(height: 8),
              Text(_progressLabel,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 14),
            ],
            SizedBox(
              height: 56,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.save_outlined),
                label: Text(_saving ? 'Saving…' : 'Save memory'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accentLight,
                  foregroundColor: AppColors.onAccent,
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  ButtonStyle get _outlined => OutlinedButton.styleFrom(
        foregroundColor: AppColors.accentLight,
        side: const BorderSide(color: AppColors.line),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      );
}
