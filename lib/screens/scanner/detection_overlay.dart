import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_theme.dart';
import '../../core/frame_mapper.dart';
import '../../models/detection.dart';

/// Draws a box and a value label for every detection, on top of the camera.
class DetectionOverlay extends StatelessWidget {
  final List<Detection> detections;

  /// Width / height of the upright camera frame.
  final double frameAspect;

  const DetectionOverlay({
    super.key,
    required this.detections,
    required this.frameAspect,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final mapper = FrameMapper(
            area: constraints.biggest,
            frameAspect: frameAspect,
          );
          // ClipRect: nothing is drawn outside the camera area.
          return ClipRect(
            child: Stack(
              children: [for (final d in detections) _place(d, mapper)],
            ),
          );
        },
      ),
    );
  }

  Widget _place(Detection d, FrameMapper mapper) {
    final rect = mapper.toArea(d.box);
    return Positioned.fromRect(
      rect: rect,
      // At the top edge a label above the box would be cut off, so it goes
      // inside the box instead.
      child: _DetectionBox(detection: d, labelInside: rect.top < 16),
    );
  }
}

class _DetectionBox extends StatelessWidget {
  final Detection detection;
  final bool labelInside;
  const _DetectionBox({required this.detection, required this.labelInside});

  @override
  Widget build(BuildContext context) {
    const c = PesoColors.dark;
    final labelColor = switch (detection.level) {
      ConfidenceLevel.high => c.success,
      ConfidenceLevel.medium => c.warning,
      ConfidenceLevel.low => c.danger,
    };

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: c.gold.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: c.gold.withValues(alpha: 0.9),
                width: 1.6,
              ),
            ),
          ),
        ),
        // The value label sits on the top-left edge of the box.
        Positioned(
          left: 6,
          top: labelInside ? 4 : -11,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: labelColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              detection.money.shortValue,
              style: AppText.mono(size: 11, color: c.background),
            ),
          ),
        ),
      ],
    );
  }
}
