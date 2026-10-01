import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_theme.dart';
import '../../core/money.dart';
import '../../widgets/gold_button.dart';

// ---------------------------------------------------------------
// Overlays drawn on top of the camera
// ---------------------------------------------------------------

/// Faint grid, like the prototype.
class GridOverlay extends StatelessWidget {
  const GridOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(painter: _GridPainter(), size: Size.infinite),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    const step = 44.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => false;
}

/// Gold L-shaped corners that frame the scanning area.
class CornerBrackets extends StatelessWidget {
  final double topInset;
  const CornerBrackets({super.key, required this.topInset});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _BracketPainter(context.colors.gold, topInset),
        size: Size.infinite,
      ),
    );
  }
}

class _BracketPainter extends CustomPainter {
  final Color color;
  final double topInset;
  _BracketPainter(this.color, this.topInset);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    const sideInset = 22.0;
    const bottomInset = 16.0;
    const length = 30.0;
    const radius = 10.0;

    // (cx, cy) is the corner; (dx, dy) points toward the middle of the screen.
    void corner(double cx, double cy, double dx, double dy) {
      final path = Path()
        ..moveTo(cx, cy + dy * length)
        ..lineTo(cx, cy + dy * radius)
        ..quadraticBezierTo(cx, cy, cx + dx * radius, cy)
        ..lineTo(cx + dx * length, cy);
      canvas.drawPath(path, paint);
    }

    corner(sideInset, topInset, 1, 1);
    corner(size.width - sideInset, topInset, -1, 1);
    corner(sideInset, size.height - bottomInset, 1, -1);
    corner(size.width - sideInset, size.height - bottomInset, -1, -1);
  }

  @override
  bool shouldRepaint(_BracketPainter old) =>
      old.color != color || old.topInset != topInset;
}

/// The glowing line that sweeps up and down.
class ScanLine extends StatelessWidget {
  final Animation<double> animation; // 0..1
  const ScanLine({super.key, required this.animation});

  @override
  Widget build(BuildContext context) {
    final gold = context.colors.gold;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) => Align(
          alignment: Alignment(0, -0.8 + 1.6 * animation.value),
          child: Container(
            height: 2,
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.transparent, gold, Colors.transparent],
              ),
              boxShadow: [
                BoxShadow(color: gold.withValues(alpha: 0.5), blurRadius: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------
// Top bar
// ---------------------------------------------------------------

class ScannerTopBar extends StatelessWidget {
  final VoidCallback onBack;
  final bool live;
  final int count;

  const ScannerTopBar({
    super.key,
    required this.onBack,
    required this.live,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                onTap: onBack,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.chevron_left_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: c.gold.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      live ? Icons.circle : Icons.circle_outlined,
                      size: 8,
                      color: c.gold,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      live ? 'LIVE' : 'SCANNING...',
                      style: AppText.mono(
                        size: 12,
                        color: c.gold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(
            width: 92,
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  '$count ${count == 1 ? 'ITEM' : 'ITEMS'}',
                  style: AppText.mono(
                    size: 12,
                    color: c.textSecondary,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HintChip extends StatelessWidget {
  final String text;
  const HintChip({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 14),
      ),
    );
  }
}

// ---------------------------------------------------------------
// Bottom: total panel and control bar
// ---------------------------------------------------------------

/// "TOTAL VALUE ₱32.25 | DETECTED 7 items", or "Waiting for detection...".
class TotalPanel extends StatelessWidget {
  final int totalCentavos;
  final int count;
  const TotalPanel({
    super.key,
    required this.totalCentavos,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      color: const Color(0xFF0A1D3A),
      child: count == 0
          ? Center(
              child: Text(
                'Waiting for detection...',
                style: TextStyle(color: c.textMuted, fontSize: 15),
              ),
            )
          : Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('TOTAL VALUE', style: text.labelSmall),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          formatPeso(totalCentavos),
                          style: AppText.mono(size: 32, color: c.gold),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('DETECTED', style: text.labelSmall),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '$count',
                          style: AppText.mono(size: 30, color: c.textPrimary),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          count == 1 ? 'item' : 'items',
                          style: AppText.mono(
                            size: 14,
                            weight: FontWeight.w500,
                            color: c.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

/// Torch (left), capture (centre), reset (right).
class ScannerControlBar extends StatelessWidget {
  final bool torchOn;
  final VoidCallback onTorch;
  final bool captureEnabled;
  final VoidCallback? onCapture;
  final VoidCallback onReset;

  const ScannerControlBar({
    super.key,
    required this.torchOn,
    required this.onTorch,
    required this.captureEnabled,
    required this.onCapture,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      color: const Color(0xFF030B1C),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _CircleButton(
                key: const Key('btn-torch'),
                icon: torchOn
                    ? Icons.flash_on_rounded
                    : Icons.flash_off_rounded,
                color: torchOn ? c.gold : c.textSecondary,
                onTap: onTorch,
              ),
              _CaptureButton(enabled: captureEnabled, onTap: onCapture),
              _CircleButton(
                key: const Key('btn-reset'),
                icon: Icons.refresh_rounded,
                color: c.textSecondary,
                onTap: onReset,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _CircleButton({
    super.key,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: const Color(0xFF111B2E),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Icon(icon, color: color, size: 26),
      ),
    );
  }
}

class _CaptureButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback? onTap;
  const _CaptureButton({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 84,
        height: 84,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
            width: 2,
          ),
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: enabled ? c.goldGradient : null,
            color: enabled ? null : const Color(0xFF111B2E),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: c.gold.withValues(alpha: 0.35),
                      blurRadius: 20,
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: enabled ? c.onGold : const Color(0xFF2F4A7A),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------
// Camera problem screen
// ---------------------------------------------------------------

class CameraErrorView extends StatelessWidget {
  final String message;
  final bool permissionProblem;
  final VoidCallback onRetry;
  final VoidCallback onOpenSettings;

  const CameraErrorView({
    super.key,
    required this.message,
    required this.permissionProblem,
    required this.onRetry,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.videocam_off_outlined, size: 54, color: c.textMuted),
            const SizedBox(height: 16),
            Text('Camera unavailable', style: text.titleLarge),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: text.bodyMedium),
            const SizedBox(height: 24),
            if (permissionProblem) ...[
              GoldButton(label: 'Open Settings', onPressed: onOpenSettings),
              const SizedBox(height: 10),
              SoftButton(label: 'Try Again', onPressed: onRetry),
            ] else
              GoldButton(label: 'Try Again', onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
