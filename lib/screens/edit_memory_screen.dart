import 'dart:io';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../models/edit_media_entry.dart';
import '../models/memory.dart';
import '../models/memory_media.dart';
import '../services/location_service.dart';
import '../services/memory_service.dart';
import '../services/place_search_service.dart';
import '../state/memory_store.dart';
import '../theme/app_theme.dart';
import '../utils/errors.dart';
import '../utils/format.dart';
import '../utils/media_utils.dart';
import '../widgets/animations.dart';
import '../widgets/app_states.dart';
import '../widgets/media_add_sheet.dart';
import '../widgets/place_autocomplete_field.dart';
import '../widgets/private_image.dart';
import 'location_picker_screen.dart';

/// Edit a memory that already exists: text, place, date and media
/// (add, remove and drag to re-order).
class EditMemoryScreen extends StatefulWidget {
  final Memory memory;
  const EditMemoryScreen({super.key, required this.memory});

  @override
  State<EditMemoryScreen> createState() => _EditMemoryScreenState();
}

class _EditMemoryScreenState extends State<EditMemoryScreen> {
  final _service = MemoryService();
  final _locationService = LocationService();

  late final TextEditingController _title =
      TextEditingController(text: widget.memory.title);
  late final TextEditingController _desc =
      TextEditingController(text: widget.memory.description ?? '');
  late final TextEditingController _locName =
      TextEditingController(text: widget.memory.locationName ?? '');

  late double _lat = widget.memory.latitude;
  late double _lng = widget.memory.longitude;
  late DateTime _date = widget.memory.displayDate.toLocal();
  late String? _pickedName = widget.memory.locationName?.trim();
  bool _locEdited = false;

  /// Everything in the story, in order (saved items + newly added ones).
  List<EditMediaEntry> _items = [];
  final List<MemoryMedia> _removed = [];
  bool _loadingMedia = true;
  String? _mediaError;

  bool _saving = false;
  bool _locating = false;
  double _progress = 0;
  String _progressLabel = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMedia();
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _locName.dispose();
    super.dispose();
  }

  Future<void> _loadMedia() async {
    setState(() {
      _loadingMedia = true;
      _mediaError = null;
    });
    try {
      final items = await _service.fetchMedia(widget.memory.id);
      items.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
      if (mounted) {
        setState(() => _items = [
              for (final m in items) EditMediaEntry.fromSaved(m),
            ]);
      }
    } catch (e) {
      if (mounted) setState(() => _mediaError = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loadingMedia = false);
    }
  }

  // ---------- media ----------

  Future<void> _addPaths(List<String> paths, String kind) async {
    String? firstError;
    for (final path in paths) {
      try {
        final d = await MediaUtils.draftFrom(path, assumed: kind);
        if (mounted) setState(() => _items.add(EditMediaEntry.fromDraft(d)));
      } catch (e) {
        firstError ??= friendlyError(e);
      }
    }
    if (firstError != null && mounted) showSnack(context, firstError);
  }

  void _removeAt(int i) {
    if (_items.length <= 1) {
      showSnack(
          context, 'A memory needs at least one photo, video or voice note.');
      return;
    }
    setState(() {
      final e = _items.removeAt(i);
      if (e.saved != null) _removed.add(e.saved!);
    });
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
          builder: (_) => LocationPickerScreen(initial: LatLng(_lat, _lng))),
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

  void _onPlaceSelected(PlaceResult r) {
    setState(() {
      _lat = r.latitude;
      _lng = r.longitude;
      _pickedName = r.name;
      _locEdited = false;
    });
  }

  /// Typed a new place but didn't tap a suggestion? Look it up and move the pin.
  Future<void> _resolveTypedLocation() async {
    final text = _locName.text.trim();
    if (text.length < 2 || !_locEdited || text == _pickedName) return;
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
    if (_title.text.trim().isEmpty) return 'Give your memory a title.';
    if (_title.text.trim().length > 150) {
      return 'Title must be 150 characters or fewer.';
    }
    if (_desc.text.length > 5000) {
      return 'Description must be 5000 characters or fewer.';
    }
    if (_items.isEmpty) {
      return 'Keep at least one photo, video or voice note.';
    }
    return null;
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (_mediaError != null || _loadingMedia) {
      setState(() => _error = "This memory's media hasn't loaded. Tap retry first.");
      return;
    }
    final problem = _validate();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
      _progress = 0;
      _progressLabel = 'Checking the place…';
    });
    try {
      await _resolveTypedLocation();
      if (mounted) setState(() => _progressLabel = 'Saving…');
      final updated = await _service.updateMemory(
        original: widget.memory,
        title: _title.text,
        description: _desc.text,
        locationName: _locName.text,
        latitude: _lat,
        longitude: _lng,
        date: DateTime(_date.year, _date.month, _date.day, 12),
        ordered: List.of(_items),
        removed: List.of(_removed),
        onProgress: (done, total, label) {
          if (!mounted) return;
          setState(() {
            _progress = total == 0 ? 0 : done / total;
            _progressLabel = label;
          });
        },
      );
      memoryStore.replaceMemory(updated);
      if (!mounted) return;
      showSnack(context, 'Memory updated.');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ---------- UI ----------

  Widget _kindTile(String kind) => Container(
        color: AppColors.elevated,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(kind == 'video' ? Icons.videocam : Icons.mic,
                size: 30, color: AppColors.accentLight),
            const SizedBox(height: 6),
            Text(kind == 'video' ? 'Video' : 'Voice',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
      );

  Widget _tile(int i) {
    final e = _items[i];
    Widget content;
    if (e.saved != null) {
      content = e.kind == 'image'
          ? PrivateImage(
              key: ValueKey('edit_${e.id}'),
              path: e.saved!.mediaPath,
              cacheWidth: 360)
          : _kindTile(e.kind);
    } else {
      final d = e.draft!;
      content = d.kind == 'image'
          ? Image.file(File(d.file.path),
              fit: BoxFit.cover,
              cacheWidth: 360,
              errorBuilder: (_, __, ___) => _kindTile('video'))
          : _kindTile(d.kind);
    }
    return Padding(
      key: ValueKey(e.id),
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
                  child: Text('${i + 1}',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ),
              if (e.isNew)
                Positioned(
                  left: 6,
                  bottom: 6,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: const Color(0xCC8B91E8),
                        borderRadius: BorderRadius.circular(10)),
                    child: const Text('New',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                ),
              Positioned(
                top: 2,
                right: 2,
                child: IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: _saving ? null : () => _removeAt(i),
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

  ButtonStyle get _outlined => OutlinedButton.styleFrom(
        foregroundColor: AppColors.accentLight,
        side: const BorderSide(color: AppColors.line),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AbsorbPointer(
          absorbing: _saving,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 4),
                  const Text('Edit memory',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 14),

              // ---- Media (drag to reorder) ----
              FadeSlideIn(
                index: 0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Photos, videos & voice',
                        style: TextStyle(
                            fontSize: 13,
                            letterSpacing: 0.6,
                            color: AppColors.textSecondary)),
                    const SizedBox(height: 10),
                    if (_loadingMedia)
                      const SizedBox(
                        height: 120,
                        child: Center(
                            child: CircularProgressIndicator(
                                color: AppColors.accentLight)),
                      )
                    else if (_mediaError != null)
                      ErrorView(message: _mediaError!, onRetry: _loadMedia)
                    else ...[
                      SizedBox(
                        height: 130,
                        child: ReorderableListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _items.length,
                          onReorder: (oldIndex, newIndex) {
                            setState(() {
                              if (newIndex > oldIndex) newIndex -= 1;
                              final item = _items.removeAt(oldIndex);
                              _items.insert(newIndex, item);
                            });
                          },
                          itemBuilder: (_, i) => _tile(i),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                                'Story order = this order. Long-press & drag to re-arrange.',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary)),
                          ),
                          TextButton.icon(
                            onPressed: () => showAddMediaSheet(context,
                                onPaths: _addPaths),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),

              FadeSlideIn(
                index: 1,
                child: Column(
                  children: [
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
                      decoration:
                          const InputDecoration(hintText: 'Description'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // ---- Location ----
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
                          const Icon(Icons.place, color: AppColors.location),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Pin set  ·  ${_lat.toStringAsFixed(4)}, ${_lng.toStringAsFixed(4)}',
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
                ),
              ),
              const SizedBox(height: 12),

              // ---- Date ----
              FadeSlideIn(
                index: 3,
                child: GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.all(18),
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
                  icon: const Icon(Icons.check),
                  label: Text(_saving ? 'Saving…' : 'Save changes'),
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
      ),
    );
  }
}
