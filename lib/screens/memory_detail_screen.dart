import 'package:flutter/material.dart';
import '../models/memory.dart';
import '../services/memory_service.dart';
import '../state/memory_store.dart';
import '../theme/app_theme.dart';
import '../utils/errors.dart';
import '../utils/format.dart';
import '../widgets/app_states.dart';
import '../widgets/private_image.dart';
import 'edit_memory_screen.dart';
import 'story_screen.dart';

/// Memory detail page (Stitch "memory detail"): hero photo + info + actions.
class MemoryDetailScreen extends StatelessWidget {
  final Memory memory;
  const MemoryDetailScreen({super.key, required this.memory});

  Future<void> _delete(BuildContext context, Memory m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Delete this memory?'),
        content: const Text(
            'The memory and all its photos, videos and voice notes will be permanently removed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete',
                  style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await MemoryService().deleteMemory(m);
      memoryStore.remove(m.id);
      if (context.mounted) Navigator.of(context).pop();
    } catch (e) {
      if (context.mounted) showSnack(context, friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: memoryStore,
      builder: (context, _) {
        final m = memoryStore.byId(memory.id) ?? memory;
        final desc = (m.description ?? '').trim();
        final height = MediaQuery.of(context).size.height;

        return Scaffold(
          body: ListView(
            padding: EdgeInsets.zero,
            children: [
              SizedBox(
                height: height * 0.46,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    PrivateImage(path: m.coverImagePath, cacheWidth: 1200),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0x99000000),
                            Color(0x00000000),
                            Color(0xFF090B12)
                          ],
                          stops: [0, 0.4, 1],
                        ),
                      ),
                    ),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Row(
                          children: [
                            _RoundIcon(
                                icon: Icons.arrow_back,
                                onTap: () => Navigator.of(context).pop()),
                            const Spacer(),
                            PopupMenuButton<String>(
                              color: AppColors.card,
                              icon: const _RoundIconBox(icon: Icons.more_horiz),
                              onSelected: (v) {
                                if (v == 'edit') {
                                  Navigator.of(context).push(MaterialPageRoute(
                                      builder: (_) =>
                                          EditMemoryScreen(memory: m)));
                                }
                                if (v == 'delete') _delete(context, m);
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Edit memory')),
                                PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete memory',
                                        style:
                                            TextStyle(color: AppColors.error))),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.title,
                        style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w600,
                            height: 1.15,
                            letterSpacing: -0.6)),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Icon(Icons.place,
                            size: 18, color: AppColors.location),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(m.locationName ?? 'Unnamed place',
                              style: const TextStyle(
                                  fontSize: 15,
                                  color: AppColors.textSecondary)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined,
                            size: 17, color: AppColors.memory),
                        const SizedBox(width: 6),
                        Text(formatDateLong(m.displayDate),
                            style: const TextStyle(
                                fontSize: 15, color: AppColors.textSecondary)),
                      ],
                    ),
                    if (desc.isNotEmpty) ...[
                      const SizedBox(height: 22),
                      Text(desc,
                          style: const TextStyle(fontSize: 17, height: 1.55)),
                    ],
                    const SizedBox(height: 22),
                    Text(m.mediaSummary,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textSecondary)),
                    const SizedBox(height: 18),
                    const Divider(color: AppColors.line, height: 1),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () async {
                            final ok = await memoryStore.toggleFavorite(m);
                            if (!ok && context.mounted) {
                              showSnack(context, 'Could not update favorite.');
                            }
                          },
                          icon: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 260),
                            transitionBuilder: (child, anim) => ScaleTransition(
                                scale: CurvedAnimation(
                                    parent: anim, curve: Curves.elasticOut),
                                child: child),
                            child: Icon(
                                m.isFavorite
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                key: ValueKey(m.isFavorite),
                                size: 28,
                                color: m.isFavorite
                                    ? AppColors.memory
                                    : AppColors.textSecondary),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Edit memory',
                          onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => EditMemoryScreen(memory: m))),
                          icon: const Icon(Icons.edit_outlined,
                              size: 26, color: AppColors.textSecondary),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: SizedBox(
                            height: 54,
                            child: FilledButton.icon(
                              onPressed: () => openStory(context, m),
                              icon: const Icon(Icons.play_arrow_rounded),
                              label: const Text('View Story'),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.accentLight,
                                foregroundColor: AppColors.onAccent,
                                textStyle: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w600),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(27)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RoundIconBox extends StatelessWidget {
  final IconData icon;
  const _RoundIconBox({required this.icon});

  @override
  Widget build(BuildContext context) => Container(
        width: 44,
        height: 44,
        decoration: const BoxDecoration(
            shape: BoxShape.circle, color: Color(0x99090B12)),
        child: Icon(icon, color: Colors.white),
      );
}

class _RoundIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundIcon({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) =>
      GestureDetector(onTap: onTap, child: _RoundIconBox(icon: icon));
}
