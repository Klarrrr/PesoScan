import '../../../models/detection.dart';

/// A camera frame handed to the detector.
/// `raw` holds the platform image data. MockDetector ignores it;
/// the real YOLO detector will use it in Part 21.
class DetectorFrame {
  final int width;
  final int height;
  final Object? raw;

  const DetectorFrame({required this.width, required this.height, this.raw});
}

/// The contract every detector must follow.
/// The UI only knows about THIS class, never about MockDetector or YOLO.
abstract class MoneyDetector {
  /// Load the model / prepare resources. Call once before detect().
  Future<void> initialize();

  /// Find coins and bills in one frame.
  Future<List<Detection>> detect(DetectorFrame frame);

  /// Free resources.
  void dispose();
}
