import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))
    ..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FadeTransition(
          opacity: CurvedAnimation(parent: _c, curve: Curves.easeOut),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppLogo(size: 108, pulse: true),
              const SizedBox(height: 22),
              const Text('Memories',
                  style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -1)),
              const SizedBox(height: 8),
              const Text('Your life, mapped.',
                  style: TextStyle(
                      fontSize: 16, color: AppColors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}
