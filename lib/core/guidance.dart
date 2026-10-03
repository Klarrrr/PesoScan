import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/detection.dart';
import '../services/frame_analyzer.dart';
import 'constants.dart';

/// The things we can tell the user. The ORDER is the priority:
/// the first active one is shown first.
enum GuidanceTip {
  itemsOutsideFrame(
    'Item partly outside the frame',
    'Move the camera so every coin and bill is inside the gold corners.',
    Icons.crop_free_rounded,
  ),
  itemsTooClose(
    'Items are too close together',
    'Spread them out. Leave at least 5 mm between items.',
    Icons.open_with_rounded,
  ),
  tooDark(
    'Too dark',
    'Turn on the flash or move to a brighter place.',
    Icons.dark_mode_outlined,
  ),
  shaky(
    'Hold steady',
    'Rest your elbows on the table and keep the phone still.',
    Icons.vibration_rounded,
  ),
  moveCloser(
    'Move a little closer',
    'Hold the camera about 20–30 cm above the items.',
    Icons.zoom_in_rounded,
  ),
  moveBack(
    'Move a little farther',
    'Hold the camera about 20–30 cm above the items.',
    Icons.zoom_out_rounded,
  ),
  tooBright(
    'Too bright or shiny',
    'Avoid glare and reflections. Tilt the phone or use softer light.',
    Icons.light_mode_outlined,
  );

  final String title;
  final String message;
  final IconData icon;
  const GuidanceTip(this.title, this.message, this.icon);
}

// How big a normal item looks at the right distance, as a share of the
// picture's height. First guesses: calibrate with the real model.
const _typicalCoinSize = 0.12;
const _typicalBillSize = 0.28;

bool _isOutside(Rect b) =>
    b.left < 0.005 || b.top < 0.005 || b.right > 0.995 || b.bottom > 0.995;

/// The frame is taller than wide, so x and y are not the same size.
/// We measure everything in "picture heights" to keep distances honest.
Rect _inHeightUnits(Rect b, double aspect) =>
    Rect.fromLTRB(b.left * aspect, b.top, b.right * aspect, b.bottom);

double _shortSide(Rect b, double aspect) =>
    math.min(b.width * aspect, b.height);

bool _anyTooClose(List<Detection> items, double aspect) {
  for (var i = 0; i < items.length; i++) {
    for (var j = i + 1; j < items.length; j++) {
      final a = items[i].box;
      final b = items[j].box;
      final gap =
          AppConstants.minGapShare *
          math.min(_shortSide(a, aspect), _shortSide(b, aspect));
      // Grow one box by the minimum gap: if it now touches the other,
      // they were closer than allowed (or already overlapping).
      if (_inHeightUnits(
        a,
        aspect,
      ).inflate(gap).overlaps(_inHeightUnits(b, aspect))) {
        return true;
      }
    }
  }
  return false;
}

double _medianSizeRatio(List<Detection> items, double aspect) {
  final ratios = [
    for (final d in items)
      _shortSide(d.box, aspect) /
          (d.money.isCoin ? _typicalCoinSize : _typicalBillSize),
  ]..sort();
  final mid = ratios.length ~/ 2;
  return ratios.length.isOdd
      ? ratios[mid]
      : (ratios[mid - 1] + ratios[mid]) / 2;
}

/// Which tips apply RIGHT NOW (before smoothing over time).
Set<GuidanceTip> evaluateGuidance({
  required List<Detection> detections,
  FrameSignals? signals,
  double frameAspect = 9 / 16,
}) {
  final tips = <GuidanceTip>{};

  if (signals != null) {
    if (signals.brightness < AppConstants.tooDarkBelow) {
      tips.add(GuidanceTip.tooDark);
    } else if (signals.brightness > AppConstants.tooBrightAbove) {
      tips.add(GuidanceTip.tooBright);
    }
    if (signals.motion > AppConstants.shakyAbove) tips.add(GuidanceTip.shaky);
  }

  if (detections.isEmpty) return tips;

  if (detections.any((d) => _isOutside(d.box))) {
    tips.add(GuidanceTip.itemsOutsideFrame);
  }
  if (_anyTooClose(detections, frameAspect)) {
    tips.add(GuidanceTip.itemsTooClose);
  }

  // Distance is judged only from items that are fully inside the picture
  // (a cut-off item looks smaller than it is).
  final whole = detections.where((d) => !_isOutside(d.box)).toList();
  if (whole.isNotEmpty) {
    final ratio = _medianSizeRatio(whole, frameAspect);
    if (ratio < 0.4) {
      tips.add(GuidanceTip.moveCloser);
    } else if (ratio > 2.3) {
      tips.add(GuidanceTip.moveBack);
    }
  }
  return tips;
}

/// Stops tips from flickering: a tip must last [showAfter] before it
/// appears, and must be gone for [hideAfter] before it disappears.
class GuidanceTracker {
  final Duration showAfter;
  final Duration hideAfter;
  final DateTime Function() _now;

  GuidanceTracker({
    this.showAfter = const Duration(milliseconds: 600),
    this.hideAfter = const Duration(milliseconds: 800),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final Map<GuidanceTip, DateTime> _since = {}; // when it first became true
  final Map<GuidanceTip, DateTime> _lastSeen = {}; // last time it was true
  final Set<GuidanceTip> _active = {};

  Set<GuidanceTip> update(Set<GuidanceTip> raw) {
    final now = _now();
    for (final tip in GuidanceTip.values) {
      if (raw.contains(tip)) {
        _since.putIfAbsent(tip, () => now);
        _lastSeen[tip] = now;
        if (now.difference(_since[tip]!) >= showAfter) _active.add(tip);
      } else {
        _since.remove(tip);
        final seen = _lastSeen[tip];
        if (seen != null && now.difference(seen) >= hideAfter) {
          _active.remove(tip);
          _lastSeen.remove(tip);
        }
      }
    }
    return Set.of(_active);
  }

  void reset() {
    _since.clear();
    _lastSeen.clear();
    _active.clear();
  }
}
