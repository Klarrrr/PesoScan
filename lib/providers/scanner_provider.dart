import 'package:flutter/foundation.dart';

import 'dart:ui' show Rect;

import '../core/constants.dart';
import '../core/guidance.dart';
import '../core/scan_math.dart' as math;
import '../models/detection.dart';
import '../services/detection_tracker.dart';
import '../services/frame_analyzer.dart';

class ScannerProvider extends ChangeNotifier {
  final DetectionTracker tracker;
  final GuidanceTracker _guidance;
  final DateTime Function() _now;

  void Function(int added)? onItemsLocked;

  double frameAspect = 9 / 16;
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
  bool _dismissedNoItems = false;

  final String? _startupError = null;
  final int _failures = 0;

  late DateTime _lastItemsAt = _now();
  DateTime _lastRun = DateTime.fromMillisecondsSinceEpoch(0);

  List<Detection> get detections => _detections;
  int get count => _detections.length;
  int get totalCentavos => math.totalCentavos(_detections);
  bool get isLive => _detections.isNotEmpty;
  bool get isReady => _ready;
  bool get isFrozen => _frozen;
  bool get hasLowConfidence => _detections.any((d) => d.isLowConfidence);

  FrameSignals? get signals => _signals;
  List<GuidanceTip> get tips => _tips;

  String? get startupError => _startupError;
  bool get hasStartupError => _startupError != null;
  bool get processingFailed => _failures >= AppConstants.failuresBeforeError;
  bool get hasProblem => hasStartupError || processingFailed;

  // Wait 10 full seconds before showing the "No coins found" message
  bool get noItemsFound =>
      _ready &&
      !_frozen &&
      !processingFailed &&
      !_dismissedNoItems &&
      _detections.isEmpty &&
      _now().difference(_lastItemsAt) >= const Duration(seconds: 10);

  bool get isDemoMode => false;
  String? get demoReason => null;

  void dismissEmptyMessage() {
    _dismissedNoItems = true;
    notifyListeners();
  }

  void start() {
    _ready = true;
    _lastItemsAt = _now();
    if (!_disposed) notifyListeners();
  }

  void retry() {
    start();
  }

  void updateDetections(List<Detection> rawDetections) {
    if (!_ready || _frozen || _disposed) return;

    // UI Frame Throttling: only redraw Flutter UI every 150ms
    // This stops the extreme FPS lag by letting the camera stay smooth!
    final now = _now();
    if (now.difference(_lastRun) < const Duration(milliseconds: 150)) return;
    _lastRun = now;

    final before = _detections.length;

    final inView = [
      for (final d in rawDetections)
        if (_visibleShare(d.box) >= AppConstants.minVisibleShare) d,
    ];

    _detections = tracker.update(inView);

    if (_detections.isNotEmpty) {
      _lastItemsAt = now;
      _dismissedNoItems = false; // Reset the "X" button if new items appear
    }

    final added = _detections.length - before;

    _refreshGuidance();
    notifyListeners();

    if (added > 0) onItemsLocked?.call(added);
  }

  // Used by the Gallery Picker to force detections into the state
  void injectAndFreeze(List<Detection> injectedDetections) {
    _detections = injectedDetections;
    _frozen = true;
    notifyListeners();
  }

  void updateSignals(FrameSignals signals) {
    if (_frozen || _disposed) return;
    _signals = signals;
    _refreshGuidance();
    notifyListeners();
  }

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

  List<Detection> freeze() {
    _frozen = true;
    notifyListeners();
    return List.unmodifiable(_detections);
  }

  void resume() {
    _frozen = false;
    reset();
  }

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
