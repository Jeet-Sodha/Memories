import 'package:flutter/material.dart';
import '../models/memory.dart';
import '../state/memory_store.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/animations.dart';
import '../widgets/app_states.dart';
import '../widgets/memory_card.dart';
import 'memory_detail_screen.dart';
import 'search_screen.dart';

/// Timeline of all memories, grouped by month, with filter chips.
class MemoriesScreen extends StatefulWidget {
  final VoidCallback onCreateTap;
  const MemoriesScreen({super.key, required this.onCreateTap});

  @override
  State<MemoriesScreen> createState() => _MemoriesScreenState();
}

class _MemoriesScreenState extends State<MemoriesScreen> {
  static const _filters = ['All', 'Photos', 'Voice', 'Favorites'];
  String _filter = 'All';

  List<Memory> _apply(List<Memory> all) {
    switch (_filter) {
      case 'Photos':
        return all.where((m) => m.imageCount > 0).toList();
      case 'Voice':
        return all.where((m) => m.audioCount > 0).toList();
      case 'Favorites':
        return all.where((m) => m.isFavorite).toList();
      default:
        return all;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: memoryStore,
        builder: (context, _) {
          final all = memoryStore.memories;
          final filtered = _apply(all);

          // Group by month (list is already newest-first).
          final groups = <String, List<Memory>>{};
          for (final m in filtered) {
            (groups[monthKey(m.displayDate)] ??= []).add(m);
          }

          Widget body;
          if (memoryStore.loading && all.isEmpty) {
            body = const Center(
                child: CircularProgressIndicator(color: AppColors.accentLight));
          } else if (memoryStore.error != null && all.isEmpty) {
            body = Center(
                child: ErrorView(
                    message: memoryStore.error!, onRetry: memoryStore.load));
          } else if (all.isEmpty) {
            body = Center(
                child: Padding(
              padding: const EdgeInsets.all(32),
              child: EmptyMemoriesView(onCreate: widget.onCreateTap),
            ));
          } else if (filtered.isEmpty) {
            body = const Center(
              child: Text('Nothing here yet.',
                  style: TextStyle(color: AppColors.textSecondary)),
            );
          } else {
            body = RefreshIndicator(
              color: AppColors.accentLight,
              backgroundColor: AppColors.card,
              onRefresh: memoryStore.load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  for (final entry in groups.entries) ...[
                    _MonthHeader(label: monthLabel(entry.value.first.displayDate)),
                    for (var i = 0; i < entry.value.length; i++)
                      _TimelineItem(
                        isLast: i == entry.value.length - 1,
                        child: FadeSlideIn(
                          index: i,
                          child: MemoryCard(
                          memory: entry.value[i],
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) =>
                                    MemoryDetailScreen(memory: entry.value[i])),
                          ),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 14, 10, 0),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text('Your Memories',
                          style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.8)),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const SearchScreen())),
                      icon: const Icon(Icons.search),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 58,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  itemCount: _filters.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final f = _filters[i];
                    final on = f == _filter;
                    return GestureDetector(
                      onTap: () => setState(() => _filter = f),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: on ? AppColors.accent : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: on ? AppColors.accent : AppColors.line),
                        ),
                        child: Text(f,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: on
                                    ? AppColors.background
                                    : AppColors.textSecondary)),
                      ),
                    );
                  },
                ),
              ),
              Expanded(child: body),
            ],
          );
        },
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  final String label;
  const _MonthHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 10),
      child: Row(
        children: [
          Container(
            width: 14,
            height: 14,
            margin: const EdgeInsets.symmetric(horizontal: 7),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.background,
              border: Border.all(color: AppColors.memory, width: 3),
            ),
          ),
          const SizedBox(width: 14),
          Text(label,
              style: const TextStyle(
                  fontSize: 13,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

/// One card with the vertical timeline rail on its left.
class _TimelineItem extends StatelessWidget {
  final Widget child;
  final bool isLast;
  const _TimelineItem({required this.child, required this.isLast});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  bottom: 0,
                  left: 13,
                  child: Container(width: 2, color: AppColors.line),
                ),
                Positioned(
                  top: 22,
                  left: 9,
                  child: Container(
                    width: 10,
                    height: 2,
                    color: AppColors.line,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}
