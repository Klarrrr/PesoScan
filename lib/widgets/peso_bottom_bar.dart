import 'package:flutter/material.dart';

import '../core/app_colors.dart';

/// Bottom bar from the prototype: Home, a raised gold Scan button,
/// History, Settings. The Scan button sticks up above the bar, so the
/// widget is taller than the bar itself ("overhang"). Keeping everything
/// inside the widget's bounds is what lets the raised button receive taps.
class PesoBottomBar extends StatelessWidget {
  static const double barHeight = 72;
  static const double overhang = 28;

  /// Screens add this much bottom padding so content scrolls above the bar.
  static double totalHeight(BuildContext context) =>
      barHeight + overhang + MediaQuery.paddingOf(context).bottom;

  /// 0 = Home, 1 = History, 2 = Settings.
  final int currentIndex;
  final ValueChanged<int> onTab;
  final VoidCallback onScan;

  const PesoBottomBar({
    super.key,
    required this.currentIndex,
    required this.onTab,
    required this.onScan,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final inset = MediaQuery.paddingOf(context).bottom;

    return SizedBox(
      height: totalHeight(context),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // The dark bar itself.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: barHeight + inset,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: c.background,
                border: Border(top: BorderSide(color: c.border)),
              ),
            ),
          ),
          // The four slots.
          Positioned(
            left: 0,
            right: 0,
            bottom: inset,
            height: barHeight + overhang,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: _NavItem(
                    key: const Key('nav-home'),
                    icon: Icons.home_rounded,
                    label: 'Home',
                    active: currentIndex == 0,
                    onTap: () => onTab(0),
                  ),
                ),
                Expanded(child: _ScanItem(onTap: onScan)),
                Expanded(
                  child: _NavItem(
                    key: const Key('nav-history'),
                    icon: Icons.history_rounded,
                    label: 'History',
                    active: currentIndex == 1,
                    onTap: () => onTab(1),
                  ),
                ),
                Expanded(
                  child: _NavItem(
                    key: const Key('nav-settings'),
                    icon: Icons.settings_rounded,
                    label: 'Settings',
                    active: currentIndex == 2,
                    onTap: () => onTab(2),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    super.key,
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = active ? c.gold : c.textMuted;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: PesoBottomBar.barHeight,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                color: color,
              ),
            ),
            const SizedBox(height: 5),
            // Small underline under the active tab.
            Container(
              width: 20,
              height: 2,
              color: active ? c.gold : Colors.transparent,
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanItem extends StatelessWidget {
  final VoidCallback onTap;
  const _ScanItem({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: PesoBottomBar.barHeight + PesoBottomBar.overhang,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: c.goldGradient,
                boxShadow: [
                  BoxShadow(
                    color: c.gold.withValues(alpha: 0.35),
                    blurRadius: 22,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                Icons.center_focus_strong_outlined,
                color: c.onGold,
                size: 30,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Scan',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: c.gold,
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
