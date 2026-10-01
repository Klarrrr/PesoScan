import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_routes.dart';
import '../../core/app_theme.dart';
import '../../core/money.dart';
import '../../core/time_labels.dart';
import '../../models/scan_record.dart';
import '../../providers/history_provider.dart';
import '../../widgets/peso_bottom_bar.dart';
import '../scanner/open_scanner.dart';

/// Page 6 of the prototype.
class HomeTab extends StatelessWidget {
  /// Asks the shell to switch tabs (1 = History, 2 = Settings).
  final ValueChanged<int> onGoToTab;
  const HomeTab({super.key, required this.onGoToTab});

  @override
  Widget build(BuildContext context) {
    final history = context.watch<HistoryProvider>();
    final sessions = history.count;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          PesoBottomBar.totalHeight(context) + 8,
        ),
        children: [
          _Header(onSettings: () => onGoToTab(2)),
          const SizedBox(height: 20),
          _StartScanCard(onTap: () => openScanner(context)),
          const SizedBox(height: 16),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _Tile(
                    icon: Icons.history_rounded,
                    title: 'History',
                    subtitle: sessions == 1
                        ? '1 session'
                        : '$sessions sessions',
                    onTap: () => onGoToTab(1),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Tile(
                    icon: Icons.menu_book_outlined,
                    title: 'Currency Guide',
                    subtitle: 'Coins & bills',
                    onTap: () => Navigator.pushNamed(context, AppRoutes.guide),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _Tile(
                    icon: Icons.bar_chart_rounded,
                    title: 'Statistics',
                    subtitle: 'Scan insights',
                    onTap: () =>
                        Navigator.pushNamed(context, AppRoutes.statistics),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Tile(
                    icon: Icons.help_outline_rounded,
                    title: 'Help & FAQ',
                    subtitle: 'Tips & guides',
                    onTap: () => Navigator.pushNamed(context, AppRoutes.help),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _SectionHeader(
            title: 'Recent Scans',
            action: 'See all',
            onAction: () => onGoToTab(1),
          ),
          const SizedBox(height: 12),
          if (history.recent.isEmpty)
            const _EmptyRecent()
          else
            for (final record in history.recent)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _RecentCard(
                  record: record,
                  onTap: () => Navigator.pushNamed(
                    context,
                    AppRoutes.historyDetail,
                    arguments: record,
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onSettings;
  const _Header({required this.onSettings});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Philippine Currency', style: text.bodyMedium),
              Text.rich(
                TextSpan(
                  style: const TextStyle(
                    fontFamily: AppFonts.heading,
                    fontWeight: FontWeight.w700,
                    fontSize: 30,
                  ),
                  children: [
                    TextSpan(
                      text: 'Peso',
                      style: TextStyle(color: c.textPrimary),
                    ),
                    TextSpan(
                      text: 'Scan',
                      style: TextStyle(color: c.gold),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: onSettings,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: c.chip,
              shape: BoxShape.circle,
              border: Border.all(color: c.border),
            ),
            child: Icon(
              Icons.settings_outlined,
              color: c.textSecondary,
              size: 22,
            ),
          ),
        ),
      ],
    );
  }
}

class _StartScanCard extends StatelessWidget {
  final VoidCallback onTap;
  const _StartScanCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final radius = BorderRadius.circular(24);

    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          gradient: c.goldGradient,
          borderRadius: radius,
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    Icons.center_focus_strong_outlined,
                    color: c.onGold,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Start Scanning',
                        style: TextStyle(
                          fontFamily: AppFonts.heading,
                          fontWeight: FontWeight.w700,
                          fontSize: 20,
                          color: c.onGold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Point camera at your coins or bills',
                        style: TextStyle(
                          fontSize: 14,
                          color: c.onGold.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: c.onGold, size: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _Tile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final radius = BorderRadius.circular(20);

    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: c.tile,
          borderRadius: radius,
          border: Border.all(color: c.border),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: c.textPrimary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: c.gold, size: 24),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: c.textSecondary.withValues(alpha: 0.75),
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

class _SectionHeader extends StatelessWidget {
  final String title;
  final String action;
  final VoidCallback onAction;

  const _SectionHeader({
    required this.title,
    required this.action,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        GestureDetector(
          onTap: onAction,
          child: Text(
            action,
            style: TextStyle(
              color: c.gold,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _RecentCard extends StatelessWidget {
  final ScanRecord record;
  final VoidCallback onTap;
  const _RecentCard({required this.record, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final radius = BorderRadius.circular(18);
    final n = record.itemCount;

    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: radius,
          border: Border.all(color: c.border),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: c.chip,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.paid_outlined, color: c.gold, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$n ${n == 1 ? 'item' : 'items'} detected',
                        style: TextStyle(
                          fontFamily: AppFonts.heading,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: c.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        scanTimeLabel(record.createdAt),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Text(
                  formatPeso(record.totalCentavos),
                  style: AppText.mono(size: 18, color: c.gold),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyRecent extends StatelessWidget {
  const _EmptyRecent();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, size: 36, color: c.textMuted),
          const SizedBox(height: 10),
          Text('No scans yet', style: text.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Tap Start Scanning to count your first coins and bills.',
            textAlign: TextAlign.center,
            style: text.bodyMedium,
          ),
        ],
      ),
    );
  }
}
