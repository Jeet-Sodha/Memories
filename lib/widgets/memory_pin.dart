import 'package:flutter/material.dart';
import '../models/memory.dart';
import '../theme/app_theme.dart';
import 'private_image.dart';

/// Circular photo marker for the map. Selected = bigger + accent ring.
class MemoryPin extends StatelessWidget {
  final Memory memory;
  final bool selected;
  final VoidCallback onTap;

  const MemoryPin({
    super.key,
    required this.memory,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final size = selected ? 56.0 : 40.0;
    // Pops in when a pin first appears.
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.4, end: 1.0),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? AppColors.accentLight : Colors.white,
              width: selected ? 3 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: selected ? const Color(0x998B91E8) : Colors.black54,
                blurRadius: selected ? 18 : 8,
                spreadRadius: selected ? 2 : 0,
              ),
            ],
          ),
          child: ClipOval(
            child: PrivateImage(
              key: ValueKey('pinimg_${memory.id}'),
              path: memory.coverImagePath,
              cacheWidth: 180,
              fallback: _NoCover(memory: memory),
            ),
          ),
        ),
      ),
      ),
    );
  }
}

/// Shown when a memory has no photo (e.g. only a video or voice note).
class _NoCover extends StatelessWidget {
  final Memory memory;
  const _NoCover({required this.memory});

  @override
  Widget build(BuildContext context) {
    final icon = memory.audioCount > 0 && memory.videoCount == 0
        ? Icons.mic
        : memory.videoCount > 0
            ? Icons.videocam
            : Icons.place;
    return Container(
      color: AppColors.memory,
      alignment: Alignment.center,
      child: Icon(icon, color: Colors.white, size: 20),
    );
  }
}

/// Several memories close together, shown as one bubble with a count.
class ClusterBubble extends StatelessWidget {
  final int count;
  final String? coverPath;
  final VoidCallback onTap;

  const ClusterBubble({
    super.key,
    required this.count,
    required this.coverPath,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.accentLight, width: 2),
            boxShadow: const [
              BoxShadow(color: Color(0x668B91E8), blurRadius: 14),
            ],
          ),
          child: ClipOval(
            child: Stack(
              fit: StackFit.expand,
              children: [
                PrivateImage(path: coverPath, cacheWidth: 200),
                Container(color: const Color(0x99090B12)),
                Center(
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
