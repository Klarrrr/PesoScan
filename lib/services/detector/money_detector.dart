import '../../models/detection.dart';

/// A camera frame handed to the detector.
/// `raw` holds the platform image data. The fake detector ignores it; the
/// real YOLO detector reads it.
class DetectorFrame {
  final int width;
  final int height;
  final Object? raw;

  /// Degrees (0, 90, 180 or 270) the picture must be turned CLOCKWISE to
  /// look upright. The real model needs it; the fake one ignores it.
  final int rotation;

  const DetectorFrame({
    required this.width,
    required this.height,
    this.raw,
    this.rotation = 0,
  });
}

/// The detector cannot start (for example the model file is missing).
/// [message] is shown to the user as it is, so keep it plain.
class ModelLoadException implements Exception {
  final String message;
  const ModelLoadException(this.message);

  @override
  String toString() => 'ModelLoadException: $message';
}

/// The contract every detector must follow.
/// The UI only knows about THIS class, never about the fake detector or YOLO.
abstract class MoneyDetector {
  /// Load the model / prepare resources. Call once before detect().
  /// Throws [ModelLoadException] if it cannot.
  Future<void> initialize();

  /// Find coins and bills in one frame.
  Future<List<Detection>> detect(DetectorFrame frame);

  /// Free resources.
  void dispose();
}

/// Implemented by detectors that INVENT their results (the fake one).
/// The scanner uses it to show the DEMO MODE badge.
abstract interface class DemoCapable {
  bool get isDemo;
  String get demoReason;

  /// Make up a brand-new scene (used by the Reset button).
  void regenerate();
}

/// Used by release builds that contain no model. It never invents results:
/// it just reports that detection is not available.
class UnavailableDetector implements MoneyDetector {
  final String message;

  const UnavailableDetector([
    this.message =
        'The detection model is not installed in this version of PesoScan.',
  ]);

  @override
  Future<void> initialize() async {
    throw ModelLoadException(message);
  }

  @override
  Future<List<Detection>> detect(DetectorFrame frame) async => const [];

  @override
  void dispose() {}
}
