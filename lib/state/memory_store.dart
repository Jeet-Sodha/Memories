import 'package:flutter/foundation.dart';
import '../models/memory.dart';
import '../services/memory_service.dart';
import '../utils/errors.dart';

/// One shared list of the user's memories used by Explore, Memories,
/// Profile and the Story viewer. Screens listen to it and rebuild.
class MemoryStore extends ChangeNotifier {
  final MemoryService _service = MemoryService();

  List<Memory> _memories = const [];
  bool _loading = false;
  bool _loadedOnce = false;
  String? _error;
  Memory? _focus; // a just-created memory the map should jump to

  List<Memory> get memories => _memories;
  bool get loading => _loading;
  bool get loadedOnce => _loadedOnce;
  String? get error => _error;

  int get placeCount {
    final names = <String>{};
    for (final m in _memories) {
      final n = (m.locationName ?? '').trim().toLowerCase();
      names.add(n.isEmpty
          ? '${m.latitude.toStringAsFixed(2)},${m.longitude.toStringAsFixed(2)}'
          : n);
    }
    return names.length;
  }

  int get favoriteCount => _memories.where((m) => m.isFavorite).length;

  /// Most-used place names, for search suggestions.
  List<String> get topPlaces {
    final counts = <String, int>{};
    for (final m in _memories) {
      final n = (m.locationName ?? '').trim();
      if (n.isNotEmpty) counts[n] = (counts[n] ?? 0) + 1;
    }
    final keys = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    return keys.take(6).toList();
  }

  Memory? byId(String id) {
    for (final m in _memories) {
      if (m.id == id) return m;
    }
    return null;
  }

  void _sort(List<Memory> l) =>
      l.sort((a, b) => b.displayDate.compareTo(a.displayDate));

  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final list = await _service.fetchMemories();
      _sort(list);
      _memories = list;
      _loadedOnce = true;
    } catch (e) {
      _error = friendlyError(e);
    }
    _loading = false;
    notifyListeners();
  }

  void addCreated(Memory m) {
    final list = [m, ..._memories];
    _sort(list);
    _memories = list;
    _focus = m;
    _loadedOnce = true;
    notifyListeners();
  }

  /// Optimistic favorite toggle. Returns false if the server rejected it.
  Future<bool> toggleFavorite(Memory m) async {
    final newValue = !m.isFavorite;
    _replace(m.copyWith(isFavorite: newValue));
    try {
      await _service.setFavorite(m.id, newValue);
      return true;
    } catch (_) {
      _replace(m.copyWith(isFavorite: m.isFavorite));
      return false;
    }
  }

  void _replace(Memory updated) {
    _memories = [for (final x in _memories) x.id == updated.id ? updated : x];
    notifyListeners();
  }

  /// Swap in an edited memory (re-sorts, since the date may have changed).
  void replaceMemory(Memory updated) {
    final list = [for (final x in _memories) x.id == updated.id ? updated : x];
    _sort(list);
    _memories = list;
    notifyListeners();
  }

  void remove(String id) {
    _memories = _memories.where((m) => m.id != id).toList();
    notifyListeners();
  }

  Memory? takeFocus() {
    final f = _focus;
    _focus = null;
    return f;
  }

  void clear() {
    _memories = const [];
    _error = null;
    _focus = null;
    _loadedOnce = false;
    notifyListeners();
  }
}

/// The single shared instance.
final MemoryStore memoryStore = MemoryStore();
