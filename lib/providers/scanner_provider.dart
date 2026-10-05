import 'package:flutter/foundation.dart';

import '../core/constants.dart';
import '../core/guidance.dart';
import '../core/scan_math.dart' as math;
import '../models/detection.dart';
import '../services/detection_tracker.dart';
import '../services/detector/money_detector.dart';
import '../services/frame_analyzer.dart';

import 'dart:ui' show Rect;

/// Runs the detector on camera frames and keeps the steady result, plus the
/// scanning tips and the "something is wrong" states.
/// One instance lives as long as the scanner screen is open.
class ScannerProvider extends ChangeNotifier {
  final MoneyDetector detector;
  final DetectionTracker tracker;

  /// Minimum time between detector runs (tests pass Duration.zero).
  final Duration minInterval;

  final DateTime Function() _now;

  /// Called when the number of confirmed items goes UP, with how many
  /// were added. The screen uses it for the haptic and the chime.
  void Function(int added)? onItemsLocked;

  /// Width / height of the upright camera picture (the screen sets it).
  double frameAspect = 9 / 16;

  /// The part of the camera picture (0..1) that is visible on screen.
  /// Only items inside it are counted, so what you see is what is counted.
  Rect visibleRegion = const Rect.fromLTWH(0, 0, 1, 1);

  ScannerProvider({
    required this.detector,
    DetectionTracker? tracker,
    this.minInterval = AppConstants.detectionInterval,
    GuidanceTracker? guidanceTracker,
    DateTime Function()? now,
  }) : tracker = tracker ?? DetectionTracker(),
       _guidance = guidanceTracker ?? GuidanceTracker(),
       _now = now ?? DateTime.now;

  final GuidanceTracker _guidance;
  List<Detection> _detections = const [];
  FrameSignals? _signals;
  List<GuidanceTip> _tips = const [];
  bool _ready = false;
  bool _busy = false;
  bool _frozen = false;
  bool _disposed = false;
  String? _startupError;
  int _failures = 0;
  DateTime _lastRun = DateTime.fromMillisecondsSinceEpoch(0);
  late DateTime _lastItemsAt = _now();

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

  // ---- Problem states -------------------------------------------------

  /// Why the detector could not start (null = it started fine).
  String? get startupError => _startupError;
  bool get hasStartupError => _startupError != null;

  /// The detector failed several times in a row.
  bool get processingFailed => _failures >= AppConstants.failuresBeforeError;

  bool get hasProblem => hasStartupError || processingFailed;

  /// Scanning for a while and nothing was found.
  bool get noItemsFound =>
      _ready &&
      !_frozen &&
      !processingFailed &&
      _detections.isEmpty &&
      _now().difference(_lastItemsAt) >= AppConstants.noItemsAfter;

  /// True while the results are invented (fake detector).
  bool get isDemoMode {
    final d = detector;
    return d is DemoCapable && (d as DemoCapable).isDemo;
  }

  String? get demoReason {
    final d = detector;
    if (d is DemoCapable) {
      final demo = d as DemoCapable;
      return demo.isDemo ? demo.demoReason : null;
    }
    return null;
  }

  // ---------------------------------------------------------------------

  /// Load the model. Frames sent before this finishes are ignored.
  /// A problem does not throw: it becomes [startupError].
  Future<void> start() async {
    _startupError = null;
    _failures = 0;
    try {
      await detector.initialize();
      _ready = true;
      _lastItemsAt = _now();
    } on ModelLoadException catch (e) {
      _ready = false;
      _startupError = e.message;
    } catch (e) {
      debugPrint('The detector could not start: $e');
      _ready = false;
      _startupError = 'The detection model could not be started.';
    }
    if (!_disposed) notifyListeners();
  }

  /// The "Try again" button.
  Future<void> retry() async {
    _ready = false;
    await start();
  }

  /// Called for every camera frame (about 30 times a second).
  /// Most are skipped: we only run when the detector is free, the minimum
  /// interval has passed, and the scan is not frozen.
  Future<void> onFrame(DetectorFrame frame) async {
    if (!_ready || _busy || _frozen || _disposed) return;

    final now = _now();
    if (now.difference(_lastRun) < minInterval) return;
    _lastRun = now;

    _busy = true;
    try {
      final raw = await detector.detect(frame);
      // The user may have frozen the scan while the detector was working.
      if (_disposed || _frozen) return;

      _failures = 0;
      final before = _detections.length;
      // Count only what is visible on screen (the preview is cropped to fit).
      final inView = [
        for (final d in raw)
          if (visibleRegion.contains(d.box.center)) d,
      ];

      _detections = tracker.update(inView);
      if (_detections.isNotEmpty) _lastItemsAt = _now();
      final added = _detections.length - before;
      _refreshGuidance();
      notifyListeners();
      if (added > 0) onItemsLocked?.call(added);
    } catch (e) {
      debugPrint('Detection failed: $e');
      _failures++;
      // Tell the screen the moment it becomes a real problem.
      if (_failures == AppConstants.failuresBeforeError && !_disposed) {
        notifyListeners();
      }
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
      visible: visibleRegion,
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
    _lastItemsAt = _now();
    // The fake detector makes up a brand-new scene so you can demo it.
    // The real detector simply sees whatever is in front of the camera.
    final d = detector;
    if (d is DemoCapable) {
      (d as DemoCapable).regenerate();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    detector.dispose();
    super.dispose();
  }
}
