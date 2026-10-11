import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/memory.dart';
import 'memory_pin.dart';

/// Draws memory pins on the map and groups nearby ones into clusters.
/// It rebuilds whenever the map camera moves/zooms (via MapCamera.of).
class MemoryMarkerLayer extends StatelessWidget {
  final List<Memory> memories;
  final String? selectedId;
  final ValueChanged<Memory> onMemoryTap;
  final ValueChanged<List<Memory>> onClusterTap;

  const MemoryMarkerLayer({
    super.key,
    required this.memories,
    required this.selectedId,
    required this.onMemoryTap,
    required this.onClusterTap,
  });

  static const double _cellSize = 64; // pixels

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);

    // Group memories into screen-space grid cells.
    final cells = <String, List<Memory>>{};
    for (final m in memories) {
      final p = camera.project(m.latLng);
      final key = '${(p.x / _cellSize).floor()}_${(p.y / _cellSize).floor()}';
      (cells[key] ??= []).add(m);
    }

    final markers = <Marker>[];
    Marker? selectedMarker;

    for (final group in cells.values) {
      if (group.length == 1) {
        final m = group.first;
        final isSel = m.id == selectedId;
        final marker = Marker(
          point: m.latLng,
          width: 64,
          height: 64,
          child: MemoryPin(
            key: ValueKey('pin_${m.id}'),
            memory: m,
            selected: isSel,
            onTap: () => onMemoryTap(m),
          ),
        );
        if (isSel) {
          selectedMarker = marker; // draw last so it sits on top
        } else {
          markers.add(marker);
        }
      } else {
        final lat =
            group.map((m) => m.latitude).reduce((a, b) => a + b) / group.length;
        final lng = group.map((m) => m.longitude).reduce((a, b) => a + b) /
            group.length;
        final cover = group
            .firstWhere((m) => m.coverImagePath != null, orElse: () => group.first)
            .coverImagePath;
        markers.add(Marker(
          point: LatLng(lat, lng),
          width: 56,
          height: 56,
          child: ClusterBubble(
            key: ValueKey('cluster_${(group.map((m) => m.id).toList()..sort()).join('|')}'),
            count: group.length,
            coverPath: cover,
            onTap: () => onClusterTap(group),
          ),
        ));
      }
    }
    if (selectedMarker != null) markers.add(selectedMarker);

    return MarkerLayer(markers: markers, rotate: true);
  }
}
