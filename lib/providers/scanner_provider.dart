import 'package:flutter/foundation.dart';

import '../core/constants.dart';
import '../core/scan_math.dart' as math;
import '../models/detection.dart';
import '../services/detection_tracker.dart';
import '../services/detector/mock_detector.dart';
import '../services/detector/money_detector.dart';

/// Runs the detector on camera frames and keeps the steady result.
/// One instance lives as long as the scanner screen is open.
class ScannerProvider extends ChangeNotifier {
  final MoneyDetector detector;
  final DetectionTracker tracker;

  /// Minimum time between detector runs (tests pass Duration.zero).
  final Duration minInterval;

  ScannerProvider({
    required this.detector,
    DetectionTracker? tracker,
    this.minInterval = AppConstants.detectionInterval,
  }) : tracker = tracker ?? DetectionTracker();

  List<Detection> _detections = const [];
  bool _ready = false;
  bool _busy = false;
  bool _disposed = false;
  DateTime _lastRun = DateTime.fromMillisecondsSinceEpoch(0);

  List<Detection> get detections => _detections;
  int get count => _detections.length;
  int get totalCentavos => math.totalCentavos(_detections);
  bool get isLive => _detections.isNotEmpty;
  bool get isReady => _ready;
  bool get hasLowConfidence => _detections.any((d) => d.isLowConfidence);

  /// Load the model. Frames sent before this finishes are ignored.
  Future<void> start() async {
    await detector.initialize();
    _ready = true;
    if (!_disposed) notifyListeners();
  }

  /// Called for every camera frame (about 30 times a second).
  /// Most are skipped: we only run when the detector is free and the
  /// minimum interval has passed.
  Future<void> onFrame(DetectorFrame frame) async {
    if (!_ready || _busy || _disposed) return;

    final now = DateTime.now();
    if (now.difference(_lastRun) < minInterval) return;
    _lastRun = now;

    _busy = true;
    try {
      final raw = await detector.detect(frame);
      if (_disposed) return;
      _detections = tracker.update(raw);
      notifyListeners();
    } catch (e) {
      debugPrint('Detection failed: $e');
    } finally {
      _busy = false;
    }
  }

  /// The Reset button: wipe the current count and start fresh.
  void reset() {
    tracker.reset();
    _detections = const [];
    // The fake detector gets a brand-new random scene so you can demo it.
    // The real detector simply sees whatever is in front of the camera.
    if (detector is MockDetector) (detector as MockDetector).regenerate();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    detector.dispose();
    super.dispose();
  }
}
