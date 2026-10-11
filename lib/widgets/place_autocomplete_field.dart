import 'dart:async';
import 'package:flutter/material.dart';
import '../services/place_search_service.dart';
import '../theme/app_theme.dart';
import '../utils/errors.dart';

/// A text field that suggests real places while you type.
/// Picking a suggestion calls [onSelected] (with coordinates).
class PlaceAutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<PlaceResult> onSelected;
  final ValueChanged<String>? onEdited;
  final String hintText;
  final Color? fillColor;
  final bool autofocus;

  const PlaceAutocompleteField({
    super.key,
    required this.controller,
    required this.onSelected,
    this.onEdited,
    this.hintText = 'Search a place…',
    this.fillColor,
    this.autofocus = false,
  });

  @override
  State<PlaceAutocompleteField> createState() => _PlaceAutocompleteFieldState();
}

class _PlaceAutocompleteFieldState extends State<PlaceAutocompleteField> {
  final PlaceSearchService _service = PlaceSearchService();
  Timer? _debounce;
  int _seq = 0; // ignore answers from older keystrokes

  List<PlaceResult> _results = const [];
  bool _loading = false;
  bool _searched = false;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    widget.onEdited?.call(value);
    _debounce?.cancel();
    if (value.trim().length < 2) {
      _seq++;
      setState(() {
        _results = const [];
        _loading = false;
        _searched = false;
        _error = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _run(value));
  }

  Future<void> _run(String value) async {
    final mySeq = ++_seq;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await _service.search(value);
      if (!mounted || mySeq != _seq) return;
      setState(() {
        _results = r;
        _loading = false;
        _searched = true;
      });
    } catch (e) {
      if (!mounted || mySeq != _seq) return;
      setState(() {
        _results = const [];
        _loading = false;
        _searched = true;
        _error = friendlyError(e);
      });
    }
  }

  void _select(PlaceResult r) {
    _debounce?.cancel();
    _seq++;
    widget.controller.text = r.name;
    widget.controller.selection =
        TextSelection.collapsed(offset: widget.controller.text.length);
    FocusScope.of(context).unfocus();
    setState(() {
      _results = const [];
      _loading = false;
      _searched = false;
      _error = null;
    });
    widget.onSelected(r);
  }

  Future<void> _submit(String value) async {
    if (_results.isEmpty && value.trim().length >= 2) await _run(value);
    if (mounted && _results.isNotEmpty) _select(_results.first);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: widget.controller,
          autofocus: widget.autofocus,
          textInputAction: TextInputAction.search,
          textCapitalization: TextCapitalization.words,
          onChanged: _onChanged,
          onSubmitted: _submit,
          decoration: InputDecoration(
            hintText: widget.hintText,
            fillColor: widget.fillColor,
            prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
            suffixIcon: _loading
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.accentLight),
                    ),
                  )
                : null,
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _buildSuggestions(),
        ),
      ],
    );
  }

  Widget _buildSuggestions() {
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 8, left: 6),
        child: Text(_error!,
            style: const TextStyle(fontSize: 13, color: AppColors.error)),
      );
    }
    if (_searched && !_loading && _results.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 8, left: 6),
        child: Text('No places found. Try another spelling, or pick on the map.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
      );
    }
    if (_results.isEmpty) return const SizedBox(width: double.infinity);

    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: AppColors.elevated,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
        boxShadow: const [
          BoxShadow(color: Color(0x66000000), blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < _results.length; i++) ...[
              if (i > 0) const Divider(height: 1, color: AppColors.line),
              InkWell(
                onTap: () => _select(_results[i]),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  child: Row(
                    children: [
                      const Icon(Icons.place_outlined,
                          size: 20, color: AppColors.location),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_results[i].name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w600)),
                            if (_results[i].subtitle.isNotEmpty)
                              Text(_results[i].subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 12.5,
                                      color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
