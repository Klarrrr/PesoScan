import 'package:flutter/foundation.dart';

import '../core/constants.dart';
import '../core/guidance.dart';
import '../core/scan_math.dart' as math;
import '../models/detection.dart';
import '../services/detection_tracker.dart';
import '../services/detector/mock_detector.dart';
import '../services/detector/money_detector.dart';
import '../services/frame_analyzer.dart';

/// Runs the detector on camera frames and keeps the steady result,
/// plus the tips that help the user scan better.
/// One instance lives as long as the scanner screen is open.
class ScannerProvider extends ChangeNotifier {
  final MoneyDetector detector;
  final DetectionTracker tracker;

  /// Minimum time between detector runs (tests pass Duration.zero).
  final Duration minInterval;

  /// Called when the number of confirmed items goes UP, with how many
  /// were added. The screen uses it for the haptic and the chime.
  void Function(int added)? onItemsLocked;

  /// Width / height of the upright camera picture (the screen sets it).
  double frameAspect = 9 / 16;

  ScannerProvider({
    required this.detector,
    DetectionTracker? tracker,
    this.minInterval = AppConstants.detectionInterval,
    GuidanceTracker? guidanceTracker,
  }) : tracker = tracker ?? DetectionTracker(),
       _guidance = guidanceTracker ?? GuidanceTracker();

  final GuidanceTracker _guidance;
  List<Detection> _detections = const [];
  FrameSignals? _signals;
  List<GuidanceTip> _tips = const [];
  bool _ready = false;
  bool _busy = false;
  bool _frozen = false;
  bool _disposed = false;
  DateTime _lastRun = DateTime.fromMillisecondsSinceEpoch(0);

  List<Detection> get detections => _detections;
  int get count => _detections.length;
  int get totalCentavos => math.totalCentavos(_detections);
  bool get isLive => _detections.isNotEmpty;
  bool get isReady => _ready;
  bool get isFrozen => _frozen;
  bool get hasLowConfidence => _detections.any((d) => d.isLowConfidence);

  /// Light and shaking, as last measured (null until the first look).
  FrameSignals? get signals => _signals;

  /// Active tips, most important first.
  List<GuidanceTip> get tips => _tips;

  /// Load the model. Frames sent before this finishes are ignored.
  Future<void> start() async {
    await detector.initialize();
    _ready = true;
    if (!_disposed) notifyListeners();
  }

  /// Called for every camera frame (about 30 times a second).
  /// Most are skipped: we only run when the detector is free, the minimum
  /// interval has passed, and the scan is not frozen.
  Future<void> onFrame(DetectorFrame frame) async {
    if (!_ready || _busy || _frozen || _disposed) return;

    final now = DateTime.now();
    if (now.difference(_lastRun) < minInterval) return;
    _lastRun = now;

    _busy = true;
    try {
      final raw = await detector.detect(frame);
      // The user may have frozen the scan while the detector was working.
      if (_disposed || _frozen) return;

      final before = _detections.length;
      _detections = tracker.update(raw);
      final added = _detections.length - before;
      _refreshGuidance();
      notifyListeners();
      if (added > 0) onItemsLocked?.call(added);
    } catch (e) {
      debugPrint('Detection failed: $e');
    } finally {
      _busy = false;
    }
  }

  /// The screen sends what it measured from the camera picture.
  void updateSignals(FrameSignals signals) {
    if (_frozen || _disposed) return;
    _signals = signals;
    _refreshGuidance();
    notifyListeners();
  }

  void _refreshGuidance() {
    final raw = evaluateGuidance(
      detections: _detections,
      signals: _signals,
      frameAspect: frameAspect,
    );
    final active = _guidance.update(raw);
    _tips = [
      for (final tip in GuidanceTip.values)
        if (active.contains(tip)) tip,
    ];
  }

  /// Stops updating and returns what was on screen at this moment.
  List<Detection> freeze() {
    _frozen = true;
    notifyListeners();
    return List.unmodifiable(_detections);
  }

  /// Back to live scanning with a clean slate.
  void resume() {
    _frozen = false;
    reset();
  }

  /// The Reset button: wipe the current count and start fresh.
  void reset() {
    tracker.reset();
    _guidance.reset();
    _detections = const [];
    _tips = const [];
    // The fake detector gets a brand-new scene so you can demo it.
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
