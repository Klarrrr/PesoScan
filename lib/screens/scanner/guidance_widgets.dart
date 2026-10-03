import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_theme.dart';
import '../../core/constants.dart';
import '../../core/guidance.dart';
import '../../services/frame_analyzer.dart';
import '../../widgets/gold_button.dart';

enum _Level { good, warn, neutral }

/// Three small indicators: light, steadiness, distance, plus a "?" button.
class ScanStatusStrip extends StatelessWidget {
  final FrameSignals? signals;
  final List<GuidanceTip> tips;
  final VoidCallback onHelp;

  const ScanStatusStrip({
    super.key,
    required this.signals,
    required this.tips,
    required this.onHelp,
  });

  @override
  Widget build(BuildContext context) {
    final hasSignals = signals != null;
    final dark = tips.contains(GuidanceTip.tooDark);
    final bright = tips.contains(GuidanceTip.tooBright);
    final shaky = tips.contains(GuidanceTip.shaky);
    final closer = tips.contains(GuidanceTip.moveCloser);
    final back = tips.contains(GuidanceTip.moveBack);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _StatusPill(
                  key: const Key('status-light'),
                  icon: Icons.wb_sunny_outlined,
                  label: !hasSignals
                      ? 'Light'
                      : dark
                      ? 'Low light'
                      : bright
                      ? 'Too bright'
                      : 'Light OK',
                  level: !hasSignals
                      ? _Level.neutral
                      : (dark || bright)
                      ? _Level.warn
                      : _Level.good,
                ),
                _StatusPill(
                  key: const Key('status-steady'),
                  icon: Icons.vibration_rounded,
                  label: !hasSignals
                      ? 'Steady?'
                      : (shaky ? 'Shaking' : 'Steady'),
                  level: !hasSignals
                      ? _Level.neutral
                      : (shaky ? _Level.warn : _Level.good),
                ),
                _StatusPill(
                  key: const Key('status-distance'),
                  icon: Icons.straighten_rounded,
                  label: closer
                      ? 'Closer'
                      : back
                      ? 'Back'
                      : AppConstants.suggestedDistance,
                  level: (closer || back) ? _Level.warn : _Level.neutral,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            key: const Key('btn-guide'),
            onTap: onHelp,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.help_outline_rounded,
                size: 19,
                color: Colors.white70,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final _Level level;

  const _StatusPill({
    super.key,
    required this.icon,
    required this.label,
    required this.level,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = switch (level) {
      _Level.good => c.success,
      _Level.warn => c.warning,
      _Level.neutral => c.textSecondary,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppText.mono(
              size: 11,
              weight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// The most important tip, as a card. "Too dark" gets a Flash button.
class GuidanceBanner extends StatelessWidget {
  final List<GuidanceTip> tips;
  final bool torchOn;
  final VoidCallback onTurnOnFlash;

  const GuidanceBanner({
    super.key,
    required this.tips,
    required this.torchOn,
    required this.onTurnOnFlash,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: tips.isEmpty
          ? const SizedBox.shrink(key: ValueKey('no-tip'))
          : Container(
              key: ValueKey(tips.first),
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: c.warning.withValues(alpha: 0.6)),
              ),
              child: Row(
                children: [
                  Icon(tips.first.icon, color: c.warning, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tips.first.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tips.first.message,
                          style: TextStyle(
                            color: c.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (tips.first == GuidanceTip.tooDark && !torchOn)
                    TextButton(
                      key: const Key('btn-tip-flash'),
                      onPressed: onTurnOnFlash,
                      child: Text('Flash on', style: TextStyle(color: c.gold)),
                    ),
                  if (tips.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        '+${tips.length - 1}',
                        style: AppText.mono(size: 12, color: c.textMuted),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

/// A dashed frame in the middle of the screen while nothing is detected,
/// showing where to put the coins and bills.
class PlacementGuide extends StatelessWidget {
  final bool visible;
  const PlacementGuide({super.key, required this.visible});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 300),
        child: CustomPaint(
          painter: _DashedFramePainter(
            context.colors.gold.withValues(alpha: 0.7),
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _DashedFramePainter extends CustomPainter {
  final Color color;
  _DashedFramePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTRB(
      size.width * 0.12,
      size.height * 0.22,
      size.width * 0.88,
      size.height * 0.66,
    );
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(26)));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    // Draw the outline as short pieces with gaps = a dashed line.
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = math.min(distance + 10, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += 18;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedFramePainter old) => old.color != color;
}

/// The "?" button opens this picture guide.
class ScanGuideSheet extends StatelessWidget {
  const ScanGuideSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ScanGuideSheet(),
    );
  }

  static const _steps = [
    (
      Icons.crop_square_rounded,
      'Use a flat, plain surface',
      'A plain white or dark table works best. Avoid patterns and shiny surfaces.',
    ),
    (
      Icons.open_with_rounded,
      'Spread the items out',
      'Leave at least 5 mm between coins and bills. Do not stack them.',
    ),
    (
      Icons.straighten_rounded,
      'Hold the camera 20–30 cm above',
      'Keep everything inside the gold corners.',
    ),
    (
      Icons.wb_sunny_outlined,
      'Use even light and stay steady',
      'Avoid shadows and glare. Rest your elbows on the table.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0A1D3A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.textMuted.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('How to scan well', style: text.titleLarge),
              const SizedBox(height: 14),
              for (final (icon, title, body) in _steps)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: c.chip,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: c.gold, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: text.titleMedium),
                            const SizedBox(height: 2),
                            Text(body, style: text.bodyMedium),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              GoldButton(
                label: 'Got it',
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
