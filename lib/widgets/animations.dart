import 'package:flutter/material.dart';

/// Fades + slides its child up when it first appears.
/// Higher [index] = slightly slower, which gives a staggered list effect.
class FadeSlideIn extends StatelessWidget {
  final Widget child;
  final int index;
  final double dy;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.index = 0,
    this.dy = 18,
  });

  @override
  Widget build(BuildContext context) {
    final ms = 380 + (index < 0 ? 0 : (index > 8 ? 8 : index)) * 70;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: ms),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0).toDouble(),
        child: Transform.translate(offset: Offset(0, dy * (1 - t)), child: child),
      ),
      child: child,
    );
  }
}

/// Shrinks slightly while pressed, then springs back.
class PressScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  const PressScale({super.key, required this.child, this.onTap});

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.96 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Used by the tab shell: the active tab fades/slides in.
class TabFade extends StatelessWidget {
  final bool active;
  final Widget child;
  const TabFade({super.key, required this.active, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: active ? 1 : 0,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
      child: AnimatedSlide(
        offset: active ? Offset.zero : const Offset(0, 0.02),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
        child: child,
      ),
    );
  }
}
