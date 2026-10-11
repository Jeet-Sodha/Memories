import 'dart:async';
import 'package:flutter/material.dart';
import '../models/memory.dart';
import '../services/memory_service.dart';
import '../state/memory_store.dart';
import '../theme/app_theme.dart';
import '../utils/errors.dart';
import '../widgets/animations.dart';
import '../widgets/app_states.dart';
import '../widgets/memory_card.dart';
import 'memory_detail_screen.dart';

/// Search by title, location name or description (own memories only).
class SearchScreen extends StatefulWidget {
  final String? initialQuery;
  const SearchScreen({super.key, this.initialQuery});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _service = MemoryService();
  final _controller = TextEditingController();
  Timer? _debounce;

  List<Memory>? _results; // null = not searching yet
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final q = widget.initialQuery;
    if (q != null && q.trim().isNotEmpty) {
      _controller.text = q;
      WidgetsBinding.instance.addPostFrameCallback((_) => _search(q));
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(v));
    setState(() {}); // update clear button
  }

  Future<void> _search(String v) async {
    final q = v.trim();
    if (q.isEmpty) {
      setState(() {
        _results = null;
        _error = null;
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await _service.search(q);
      if (!mounted || _controller.text.trim() != q) return;
      setState(() {
        _results = r;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyError(e);
        _loading = false;
      });
    }
  }

  void _open(Memory m) => Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => MemoryDetailScreen(memory: m)));

  Widget _grid(List<Memory> list) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.78,
      ),
      itemCount: list.length,
      itemBuilder: (_, i) => FadeSlideIn(
        index: i,
        child: MemoryGridTile(memory: list[i], onTap: () => _open(list[i])),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_loading) {
      body = const Center(
          child: CircularProgressIndicator(color: AppColors.accentLight));
    } else if (_error != null) {
      body = Center(
          child: ErrorView(
              message: _error!, onRetry: () => _search(_controller.text)));
    } else if (_results != null) {
      body = _results!.isEmpty
          ? const Center(
              child: Text('No matching memories.',
                  style: TextStyle(color: AppColors.textSecondary)))
          : _grid(_results!);
    } else {
      final recent = memoryStore.memories.take(8).toList();
      final places = memoryStore.topPlaces;
      body = ListView(
        children: [
          if (places.isNotEmpty)
            SizedBox(
              height: 52,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                itemCount: places.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => ActionChip(
                  backgroundColor: AppColors.card,
                  side: const BorderSide(color: AppColors.line),
                  avatar: const Icon(Icons.place,
                      size: 16, color: AppColors.location),
                  label: Text(places[i]),
                  onPressed: () {
                    _controller.text = places[i];
                    _search(places[i]);
                  },
                ),
              ),
            ),
          if (recent.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(22, 14, 22, 6),
              child: Text('Recent Memories',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.78,
              ),
              itemCount: recent.length,
              itemBuilder: (_, i) => MemoryGridTile(
                  memory: recent[i], onTap: () => _open(recent[i])),
            ),
          ] else
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(
                child: Text('Search your places, titles and descriptions.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
            ),
        ],
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 20, 6),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      autofocus: widget.initialQuery == null,
                      textInputAction: TextInputAction.search,
                      onChanged: _onChanged,
                      onSubmitted: _search,
                      decoration: InputDecoration(
                        hintText: 'Search places, memories…',
                        prefixIcon: const Icon(Icons.search,
                            color: AppColors.textSecondary),
                        suffixIcon: _controller.text.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.close,
                                    color: AppColors.textSecondary),
                                onPressed: () {
                                  _controller.clear();
                                  _search('');
                                },
                              ),
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(28),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(28),
                          borderSide: const BorderSide(color: AppColors.accent),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}
