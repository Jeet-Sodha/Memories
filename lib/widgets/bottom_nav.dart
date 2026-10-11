import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// Floating pill navigation bar. The selected tab expands to show its label,
/// and Create is a raised round button in the middle.
class BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const BottomNav({super.key, required this.currentIndex, required this.onTap});

  void _tap(int i) {
    if (i != currentIndex) HapticFeedback.selectionClick();
    onTap(i);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
        child: Container(
          height: 68,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: const Color(0xF2151923),
            borderRadius: BorderRadius.circular(34),
            border: Border.all(color: AppColors.line),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x99000000),
                  blurRadius: 24,
                  offset: Offset(0, 8)),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _NavItem(
                icon: Icons.explore_outlined,
                activeIcon: Icons.explore,
                label: 'Explore',
                selected: currentIndex == 0,
                onTap: () => _tap(0),
              ),
              _NavItem(
                icon: Icons.auto_stories_outlined,
                activeIcon: Icons.auto_stories,
                label: 'Memories',
                selected: currentIndex == 1,
                onTap: () => _tap(1),
              ),
              _CreateButton(selected: currentIndex == 2, onTap: () => _tap(2)),
              _NavItem(
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                label: 'Profile',
                selected: currentIndex == 3,
                onTap: () => _tap(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0x338B91E8) : Colors.transparent,
          borderRadius: BorderRadius.circular(23),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                selected ? activeIcon : icon,
                key: ValueKey(selected),
                size: 24,
                color:
                    selected ? AppColors.accentLight : AppColors.textSecondary,
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              child: selected
                  ? Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        label,
                        maxLines: 1,
                        softWrap: false,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accentLight,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateButton extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  const _CreateButton({required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.accentLight,
          boxShadow: [
            BoxShadow(
              color: selected
                  ? const Color(0x998B91E8)
                  : const Color(0x338B91E8),
              blurRadius: selected ? 20 : 10,
            ),
          ],
        ),
        child: AnimatedRotation(
          turns: selected ? 0.125 : 0,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          child: const Icon(Icons.add, color: AppColors.onAccent, size: 30),
        ),
      ),
    );
  }
}
