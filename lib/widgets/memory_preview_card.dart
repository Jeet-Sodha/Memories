import 'package:flutter/material.dart';
import '../models/memory.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import 'private_image.dart';

/// Bottom card shown when a map pin is selected.
class MemoryPreviewCard extends StatelessWidget {
  final Memory memory;
  final VoidCallback onViewStory;
  final VoidCallback onOpenDetails;
  final VoidCallback onClose;

  const MemoryPreviewCard({
    super.key,
    required this.memory,
    required this.onViewStory,
    required this.onOpenDetails,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final desc = (memory.description ?? '').trim();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xF21C2230),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.line),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 24, offset: Offset(0, 8)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onOpenDetails,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: SizedBox(
                    width: 92,
                    height: 92,
                    child: PrivateImage(
                        path: memory.coverImagePath, cacheWidth: 300),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              memory.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w600,
                                  height: 1.2),
                            ),
                          ),
                          GestureDetector(
                            onTap: onClose,
                            child: const Padding(
                              padding: EdgeInsets.only(left: 6),
                              child: Icon(Icons.close,
                                  size: 20, color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.place,
                              size: 15, color: AppColors.location),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              memory.locationName ?? 'Unnamed place',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 13, color: AppColors.textSecondary),
                            ),
                          ),
                          const Text('  •  ',
                              style: TextStyle(color: AppColors.textSecondary)),
                          Text(formatDate(memory.displayDate),
                              style: const TextStyle(
                                  fontSize: 13, color: AppColors.textSecondary)),
                        ],
                      ),
                      if (desc.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          '"$desc"',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                              color: AppColors.textSecondary,
                              height: 1.35),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(memory.mediaSummary,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary)),
              ),
              FilledButton.icon(
                onPressed: onViewStory,
                icon: const Icon(Icons.play_arrow_rounded, size: 20),
                label: const Text('View Story'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accentLight,
                  foregroundColor: AppColors.onAccent,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24)),
                  textStyle: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
