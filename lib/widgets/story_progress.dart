import 'package:flutter/material.dart';

/// ━━━ ━━━ ━━━  Snapchat/Instagram-style progress bars.
class StoryProgress extends StatelessWidget {
  final int count;
  final int currentIndex;
  final Animation<double> progress;

  const StoryProgress({
    super.key,
    required this.count,
    required this.currentIndex,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(count, (i) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i == count - 1 ? 0 : 4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: SizedBox(
                height: 3,
                child: i == currentIndex
                    ? AnimatedBuilder(
                        animation: progress,
                        builder: (_, __) => LinearProgressIndicator(
                          value: progress.value,
                          backgroundColor: const Color(0x4DFFFFFF),
                          valueColor:
                              const AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : LinearProgressIndicator(
                        value: i < currentIndex ? 1 : 0,
                        backgroundColor: const Color(0x4DFFFFFF),
                        valueColor: const AlwaysStoppedAnimation(Colors.white),
                      ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
