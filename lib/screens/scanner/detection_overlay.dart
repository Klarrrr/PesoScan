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
          return Stack(
            clipBehavior: Clip.none,
            children: [
              for (final d in detections)
                Positioned.fromRect(
                  rect: mapper.toArea(d.box),
                  child: _DetectionBox(detection: d),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _DetectionBox extends StatelessWidget {
  final Detection detection;
  const _DetectionBox({required this.detection});

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
          top: -11,
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
