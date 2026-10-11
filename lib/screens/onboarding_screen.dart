import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Shown once, before the first login. Matches the Stitch onboarding.
class OnboardingScreen extends StatefulWidget {
  /// signUp = true -> go to "create account"; false -> go to "log in".
  final void Function(bool signUp) onDone;
  const OnboardingScreen({super.key, required this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _Page {
  final String title;
  final String body;
  final IconData icon;
  final String chipA;
  final IconData chipAIcon;
  final String chipB;
  final IconData chipBIcon;
  const _Page(this.title, this.body, this.icon, this.chipA, this.chipAIcon,
      this.chipB, this.chipBIcon);
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _pages = [
    _Page(
      'Places remember what we forget.',
      'Capture moments, attach them to places, and build a map of your memories.',
      Icons.photo_outlined,
      'Marine Drive',
      Icons.place,
      '18 Aug 2026',
      Icons.calendar_today,
    ),
    _Page(
      'Every memory has an address.',
      'Photos, videos and voice notes live exactly where they happened.',
      Icons.map_outlined,
      'Lonavala',
      Icons.place,
      '5 photos · 1 video',
      Icons.collections_outlined,
    ),
    _Page(
      'Relive it as a story.',
      'Tap a place on your map and play it back, privately. Only you can see it.',
      Icons.play_circle_outline,
      'Private',
      Icons.lock_outline,
      'View Story',
      Icons.play_arrow,
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final last = _page == _pages.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) => _PageView(page: _pages[i]),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pages.length, (i) {
                final on = i == _page;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: on ? 22 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: on ? AppColors.accentLight : AppColors.elevated,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton(
                      onPressed: () {
                        if (last) {
                          widget.onDone(true);
                        } else {
                          _controller.nextPage(
                              duration: const Duration(milliseconds: 350),
                              curve: Curves.easeOut);
                        }
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.accentLight,
                        foregroundColor: AppColors.onAccent,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28)),
                      ),
                      child: Text(last ? 'Begin your journey' : 'Next',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => widget.onDone(false),
                    child: const Text('I already have an account',
                        style: TextStyle(color: AppColors.textSecondary)),
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

class _PageView extends StatelessWidget {
  final _Page page;
  const _PageView({required this.page});

  Widget _chip(IconData icon, String text, Color iconColor) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: iconColor),
            const SizedBox(width: 6),
            Text(text, style: const TextStyle(fontSize: 13)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: _Bob(child: SizedBox(
                width: 250,
                height: 330,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: Transform.rotate(
                        angle: 0.05,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(32),
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF2A2F5E), Color(0xFF151923)],
                            ),
                            border: Border.all(color: AppColors.line),
                          ),
                          child: Icon(page.icon,
                              size: 72, color: AppColors.accentLight),
                        ),
                      ),
                    ),
                    Positioned(
                        top: -10,
                        left: -18,
                        child: _chip(page.chipAIcon, page.chipA,
                            AppColors.location)),
                    Positioned(
                        bottom: 16,
                        right: -18,
                        child: _chip(page.chipBIcon, page.chipB,
                            AppColors.memory)),
                  ],
                ),
              )),
            ),
          ),
          Text(page.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 30,
                  height: 1.15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.8,
                  color: AppColors.accentLight)),
          const SizedBox(height: 14),
          Text(page.body,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 16, height: 1.45, color: AppColors.textSecondary)),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}


/// Makes its child float up and down slowly.
class _Bob extends StatefulWidget {
  final Widget child;
  const _Bob({required this.child});

  @override
  State<_Bob> createState() => _BobState();
}

class _BobState extends State<_Bob> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2600))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (_, child) => Transform.translate(
        offset: Offset(0, -10 * Curves.easeInOut.transform(_c.value)),
        child: child,
      ),
    );
  }
}
