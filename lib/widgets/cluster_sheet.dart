import 'package:flutter/material.dart';
import '../models/memory.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import 'private_image.dart';

/// Bottom sheet listing memories that were grouped together on the map.
class ClusterSheet extends StatelessWidget {
  final List<Memory> memories;
  final ValueChanged<Memory> onSelect;
  final VoidCallback? onViewAll;

  const ClusterSheet({
    super.key,
    required this.memories,
    required this.onSelect,
    this.onViewAll,
  });

  static Future<void> show(
    BuildContext context, {
    required List<Memory> memories,
    required ValueChanged<Memory> onSelect,
    VoidCallback? onViewAll,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => ClusterSheet(
          memories: memories, onSelect: onSelect, onViewAll: onViewAll),
    );
  }

  String get _title {
    final counts = <String, int>{};
    for (final m in memories) {
      final n = (m.locationName ?? '').trim();
      if (n.isNotEmpty) counts[n] = (counts[n] ?? 0) + 1;
    }
    if (counts.isEmpty) return 'Nearby memories';
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  @override
  Widget build(BuildContext context) {
    final sorted = [...memories]
      ..sort((a, b) => b.displayDate.compareTo(a.displayDate));
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.line, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_title,
                      style: const TextStyle(
                          fontSize: 26, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.collections_outlined,
                          size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Text('${memories.length} memories clustered here',
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.textSecondary)),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 270,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 22),
                itemCount: sorted.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) {
                  final m = sorted[i];
                  return GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop();
                      onSelect(m);
                    },
                    child: SizedBox(
                      width: 190,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            PrivateImage(
                                path: m.coverImagePath, cacheWidth: 500),
                            const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Color(0x00000000), Color(0xE6090B12)],
                                  stops: [0.35, 1],
                                ),
                              ),
                            ),
                            Positioned(
                              left: 14,
                              right: 14,
                              bottom: 14,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(formatDate(m.displayDate),
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.accentLight)),
                                  const SizedBox(height: 4),
                                  Text(m.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w600,
                                          height: 1.2)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (onViewAll != null)
              Center(
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onViewAll!();
                  },
                  icon: const Icon(Icons.arrow_forward,
                      size: 18, color: AppColors.accentLight),
                  label: Text('VIEW ALL ${memories.length} MEMORIES',
                      style: const TextStyle(
                          color: AppColors.accentLight,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
