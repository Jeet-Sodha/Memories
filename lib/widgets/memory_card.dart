import 'package:flutter/material.dart';
import '../models/memory.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import 'animations.dart';
import 'private_image.dart';

/// Wide card used in the Memories timeline.
class MemoryCard extends StatelessWidget {
  final Memory memory;
  final VoidCallback onTap;

  const MemoryCard({super.key, required this.memory, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    PrivateImage(path: memory.coverImagePath, cacheWidth: 800),
                    if (memory.isFavorite)
                      const Positioned(
                        top: 10,
                        right: 10,
                        child: Icon(Icons.favorite,
                            color: AppColors.memory, size: 22),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatDate(memory.displayDate),
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accentLight),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      memory.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w600, height: 1.25),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.place,
                            size: 14, color: AppColors.location),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            memory.locationName ?? 'Unnamed place',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13, color: AppColors.textSecondary),
                          ),
                        ),
                        Text(memory.mediaSummary,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tall photo tile used in Search results.
class MemoryGridTile extends StatelessWidget {
  final Memory memory;
  final VoidCallback onTap;

  const MemoryGridTile({super.key, required this.memory, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            PrivateImage(path: memory.coverImagePath, cacheWidth: 500),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00000000), Color(0xD9090B12)],
                  stops: [0.45, 1],
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(memory.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600, height: 1.2)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.place, size: 12, color: AppColors.location),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(memory.locationName ?? 'Unnamed place',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textSecondary)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
