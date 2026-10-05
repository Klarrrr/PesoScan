import 'dart:math' as math;
import 'dart:ui';

/// Converts a box from the camera frame (0..1) to pixels on the screen area.
///
/// The preview is shown with BoxFit.cover: scaled until it FILLS the area,
/// so the long side is cropped. The mapper repeats that same maths.
class FrameMapper {
  /// The screen area showing the camera, in pixels.
  final Size area;

  /// Width divided by height of the UPRIGHT camera frame (e.g. 9/16).
  final double frameAspect;

  const FrameMapper({required this.area, required this.frameAspect});

  /// Size the whole frame would have after scaling to cover the area.
  Size get displaySize {
    final areaAspect = area.width / area.height;
    if (areaAspect > frameAspect) {
      // Area is wider than the frame: fit the width, crop top and bottom.
      return Size(area.width, area.width / frameAspect);
    }
    // Area is taller: fit the height, crop left and right.
    return Size(area.height * frameAspect, area.height);
  }

  /// Where the scaled frame starts (negative = cropped off-screen).
  Offset get offset {
    final d = displaySize;
    return Offset((area.width - d.width) / 2, (area.height - d.height) / 2);
  }

  Rect toArea(Rect normalized) {
    final d = displaySize;
    final o = offset;
    return Rect.fromLTRB(
      o.dx + normalized.left * d.width,
      o.dy + normalized.top * d.height,
      o.dx + normalized.right * d.width,
      o.dy + normalized.bottom * d.height,
    );
  }

  /// The part of the camera picture (0..1) that can really be seen in the
  /// area. The rest is cropped off, so nothing there should be counted.
  Rect get visibleFrameRect {
    final d = displaySize;
    final o = offset;
    return Rect.fromLTRB(
      math.max(0.0, -o.dx / d.width),
      math.max(0.0, -o.dy / d.height),
      math.min(1.0, (area.width - o.dx) / d.width),
      math.min(1.0, (area.height - o.dy) / d.height),
    );
  }
}
