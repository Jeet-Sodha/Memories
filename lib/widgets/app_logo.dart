import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// The Memories logo (assets/app_icon.png).
/// [pulse] makes it gently "breathe" (used on loading screens).
class AppLogo extends StatefulWidget {
  final double size;
  final bool pulse;
  const AppLogo({super.key, this.size = 96, this.pulse = false});

  @override
  State<AppLogo> createState() => _AppLogoState();
}

class _AppLogoState extends State<AppLogo> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1600));

  @override
  void initState() {
    super.initState();
    if (widget.pulse) _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logo = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.size * 0.24),
        boxShadow: const [
          BoxShadow(color: Color(0x558B91E8), blurRadius: 36),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.size * 0.24),
        child: Image.asset(
          'assets/app_icon.png',
          width: widget.size,
          height: widget.size,
          fit: BoxFit.cover,
          // If the asset is ever missing the app still works.
          errorBuilder: (_, __, ___) => Container(
            color: AppColors.card,
            alignment: Alignment.center,
            child: Icon(Icons.place,
                size: widget.size * 0.5, color: AppColors.accentLight),
          ),
        ),
      ),
    );
    if (!widget.pulse) return logo;
    return ScaleTransition(
      scale: Tween<double>(begin: 0.94, end: 1.03).animate(
          CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
      child: logo,
    );
  }
}
