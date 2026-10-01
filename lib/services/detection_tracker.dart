import 'dart:ui';

import '../models/detection.dart';

/// How much two boxes overlap: 0 = not at all, 1 = identical.
double intersectionOverUnion(Rect a, Rect b) {
  if (!a.overlaps(b)) return 0;
  final inter = a.intersect(b);
  final interArea = inter.width * inter.height;
  final unionArea = a.width * a.height + b.width * b.height - interArea;
  return unionArea <= 0 ? 0 : interArea / unionArea;
}

class _Track {
  Detection detection;
  int hits = 1; // frames in which it was seen
  int misses = 0; // frames in a row in which it was missed
  _Track(this.detection);
}

/// Turns jittery per-frame detections into steady ones.
/// - A coin must be seen `confirmHits` times before it is shown.
/// - Its box and confidence are smoothed.
/// - It stays visible for `maxMisses` frames after it disappears.
class DetectionTracker {
  final double iouThreshold;
  final int confirmHits;
  final int maxMisses;

  /// 0..1: how strongly a new frame pulls the box (1 = no smoothing).
  final double smoothing;

  DetectionTracker({
    this.iouThreshold = 0.3,
    this.confirmHits = 3,
    this.maxMisses = 4,
    this.smoothing = 0.5,
  });

  final List<_Track> _tracks = [];

  /// Give it this frame's raw detections; get back the steady ones.
  List<Detection> update(List<Detection> raw) {
    // 1. Score every (existing track, new detection) pair by overlap.
    final pairs = <(int, int, double)>[];
    for (var t = 0; t < _tracks.length; t++) {
      for (var d = 0; d < raw.length; d++) {
        final score = intersectionOverUnion(
          _tracks[t].detection.box,
          raw[d].box,
        );
        if (score >= iouThreshold) pairs.add((t, d, score));
      }
    }

    // 2. Best overlaps first; each track and detection is used only once.
    pairs.sort((a, b) => b.$3.compareTo(a.$3));
    final usedTracks = <int>{};
    final usedDetections = <int>{};
    for (final (t, d, _) in pairs) {
      if (usedTracks.contains(t) || usedDetections.contains(d)) continue;
      usedTracks.add(t);
      usedDetections.add(d);
      _merge(_tracks[t], raw[d]);
    }

    // 3. Tracks nobody matched were missed this frame.
    for (var t = 0; t < _tracks.length; t++) {
      if (!usedTracks.contains(t)) _tracks[t].misses++;
    }

    // 4. Detections nobody matched start new tracks.
    for (var d = 0; d < raw.length; d++) {
      if (!usedDetections.contains(d)) _tracks.add(_Track(raw[d]));
    }

    // 5. Forget tracks missing for too long; show the confirmed ones.
    _tracks.removeWhere((t) => t.misses > maxMisses);
    return [
      for (final t in _tracks)
        if (t.hits >= confirmHits) t.detection,
    ];
  }

  void reset() => _tracks.clear();

  void _merge(_Track track, Detection fresh) {
    final old = track.detection;
    track.detection = Detection(
      money: fresh.money,
      confidence:
          old.confidence + (fresh.confidence - old.confidence) * smoothing,
      box: Rect.lerp(old.box, fresh.box, smoothing)!,
    );
    track.hits++;
    track.misses = 0;
  }
}
