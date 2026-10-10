import 'package:flutter/foundation.dart';

import 'dart:ui' show Rect;

import '../core/constants.dart';
import '../core/guidance.dart';
import '../core/scan_math.dart' as math;
import '../models/detection.dart';
import '../services/detection_tracker.dart';
import '../services/frame_analyzer.dart';

/// Manages the state of the scanner screen, receiving detections from YOLOView.
/// Keeps the steady result, plus the scanning tips and the "something is wrong" states.
class ScannerProvider extends ChangeNotifier {
  final DetectionTracker tracker;
  final GuidanceTracker _guidance;
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
    DetectionTracker? tracker,
    GuidanceTracker? guidanceTracker,
    DateTime Function()? now,
  }) : tracker = tracker ?? DetectionTracker(),
       _guidance = guidanceTracker ?? GuidanceTracker(),
       _now = now ?? DateTime.now;

  List<Detection> _detections = const [];
  FrameSignals? _signals;
  List<GuidanceTip> _tips = const [];

  bool _ready = false;
  bool _frozen = false;
  bool _disposed = false;

  final String? _startupError = null;
  final int _failures = 0;

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

  String? get startupError => _startupError;
  bool get hasStartupError => _startupError != null;
  bool get processingFailed => _failures >= AppConstants.failuresBeforeError;
  bool get hasProblem => hasStartupError || processingFailed;

  /// Scanning for a while and nothing was found.
  bool get noItemsFound =>
      _ready &&
      !_frozen &&
      !processingFailed &&
      _detections.isEmpty &&
      _now().difference(_lastItemsAt) >= AppConstants.noItemsAfter;

  // YOLOView integration no longer utilizes the mock/demo detector logic
  bool get isDemoMode => false;
  String? get demoReason => null;

  // ---------------------------------------------------------------------

  /// Marks the provider as ready. YOLOView handles the actual model loading natively.
  void start() {
    _ready = true;
    _lastItemsAt = _now();
    if (!_disposed) notifyListeners();
  }

  /// The "Try again" button logic.
  void retry() {
    start();
  }

  /// Receives the translated YOLO detections directly from the ScannerScreen.
  void updateDetections(List<Detection> rawDetections) {
    if (!_ready || _frozen || _disposed) return;

    final before = _detections.length;

    // Count every item that is at least partly visible on screen, even if
    // the edge of the picture cuts it off.
    final inView = [
      for (final d in rawDetections)
        if (_visibleShare(d.box) >= AppConstants.minVisibleShare) d,
    ];

    _detections = tracker.update(inView);

    if (_detections.isNotEmpty) _lastItemsAt = _now();
    final added = _detections.length - before;

    _refreshGuidance();
    notifyListeners();

    if (added > 0) onItemsLocked?.call(added);
  }

  /// The screen sends what it measured from the camera picture.
  void updateSignals(FrameSignals signals) {
    if (_frozen || _disposed) return;
    _signals = signals;
    _refreshGuidance();
    notifyListeners();
  }

  /// How much of [box] (0..1) lies inside the visible part of the picture.
  double _visibleShare(Rect box) {
    final area = box.width * box.height;
    if (area <= 0 || !box.overlaps(visibleRegion)) return 0;
    final inside = box.intersect(visibleRegion);
    return inside.width * inside.height / area;
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
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
