import 'dart:typed_data';

/// What we learned from looking at one camera picture.
class FrameSignals {
  /// 0 (black) to 255 (white).
  final double brightness;

  /// How much the picture changed since the last look (0 = still).
  final double motion;

  const FrameSignals({required this.brightness, required this.motion});
}

/// Measures brightness and shaking from the camera's brightness plane.
/// It only looks at a small grid of points (24 x 32), so it is very fast.
/// It knows nothing about the camera plugin, so it can be tested with
/// ordinary byte lists.
class FrameAnalyzer {
  static const _gridX = 24;
  static const _gridY = 32;

  List<int>? _previous;
  double _smoothBrightness = -1;
  double _smoothMotion = 0;

  /// [bytes] is the brightness plane; [rowStride] is the bytes per row and
  /// [pixelStride] the bytes per pixel (1 on Android).
  FrameSignals analyze({
    required Uint8List bytes,
    required int width,
    required int height,
    required int rowStride,
    int pixelStride = 1,
  }) {
    final samples = List<int>.filled(_gridX * _gridY, 0);
    var sum = 0;

    for (var gy = 0; gy < _gridY; gy++) {
      final y = ((gy + 0.5) * height / _gridY).floor();
      for (var gx = 0; gx < _gridX; gx++) {
        final x = ((gx + 0.5) * width / _gridX).floor();
        final index = y * rowStride + x * pixelStride;
        final value = index < bytes.length ? bytes[index] : 0;
        samples[gy * _gridX + gx] = value;
        sum += value;
      }
    }

    final brightness = sum / samples.length;

    var motion = 0.0;
    final previous = _previous;
    if (previous != null) {
      var difference = 0;
      for (var i = 0; i < samples.length; i++) {
        difference += (samples[i] - previous[i]).abs();
      }
      motion = difference / samples.length;
    }
    _previous = samples;

    // Smooth both numbers so a single odd picture does not make them jump.
    _smoothBrightness = _smoothBrightness < 0
        ? brightness
        : _smoothBrightness * 0.5 + brightness * 0.5;
    _smoothMotion = _smoothMotion * 0.5 + motion * 0.5;

    return FrameSignals(brightness: _smoothBrightness, motion: _smoothMotion);
  }

  void reset() {
    _previous = null;
    _smoothBrightness = -1;
    _smoothMotion = 0;
  }
}
