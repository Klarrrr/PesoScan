import 'dart:ui' show Rect, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:pesoscan/core/frame_mapper.dart';
import 'package:pesoscan/core/scan_math.dart';
import 'package:pesoscan/models/detection.dart';
import 'package:pesoscan/models/money_class.dart';
import 'package:pesoscan/providers/scanner_provider.dart';
import 'package:pesoscan/services/detection_tracker.dart';
import 'package:pesoscan/services/detector/mock_detector.dart';
import 'package:pesoscan/services/detector/money_detector.dart';

Detection det(Rect box, {double conf = 0.9, int classId = 7}) =>
    Detection(money: MoneyClasses.byId(classId), confidence: conf, box: box);

void main() {
  group('intersectionOverUnion', () {
    test('identical, disjoint and half-overlapping boxes', () {
      const a = Rect.fromLTRB(0, 0, 1, 1);
      expect(intersectionOverUnion(a, a), 1);
      expect(intersectionOverUnion(a, const Rect.fromLTRB(2, 2, 3, 3)), 0);
      expect(
        intersectionOverUnion(a, const Rect.fromLTRB(0.5, 0, 1.5, 1)),
        closeTo(1 / 3, 0.0001),
      );
    });
  });

  group('DetectionTracker', () {
    const box = Rect.fromLTRB(0.1, 0.1, 0.3, 0.3);

    test('shows a coin only after it is seen several times', () {
      final tracker = DetectionTracker(confirmHits: 3);
      expect(tracker.update([det(box)]), isEmpty);
      expect(tracker.update([det(box)]), isEmpty);
      expect(tracker.update([det(box)]).length, 1);
    });

    test('keeps a coin through short gaps, then forgets it', () {
      final tracker = DetectionTracker(confirmHits: 3, maxMisses: 2);
      for (var i = 0; i < 3; i++) {
        tracker.update([det(box)]);
      }
      expect(tracker.update([]).length, 1); // missed once
      expect(tracker.update([]).length, 1); // missed twice
      expect(tracker.update([]), isEmpty); // gone
    });

    test('two separate coins are tracked separately', () {
      final tracker = DetectionTracker(confirmHits: 2);
      const other = Rect.fromLTRB(0.6, 0.6, 0.8, 0.8);
      tracker.update([det(box), det(other, classId: 4)]);
      final result = tracker.update([det(box), det(other, classId: 4)]);
      expect(result.length, 2);
    });

    test('smooths the box between frames', () {
      final tracker = DetectionTracker(confirmHits: 1, smoothing: 0.5);
      tracker.update([det(box)]);
      final moved = box.shift(const Offset(0.02, 0));
      final result = tracker.update([det(moved)]);
      expect(result.first.box.left, closeTo(0.11, 0.0001)); // halfway
    });

    test('reset clears everything', () {
      final tracker = DetectionTracker(confirmHits: 1);
      tracker.update([det(box)]);
      tracker.reset();
      expect(tracker.update([]), isEmpty);
    });
  });

  group('FrameMapper', () {
    test('a wider area crops the top and bottom of the frame', () {
      // 9:16 frame shown in a 400x600 area (wider than the frame).
      const mapper = FrameMapper(area: Size(400, 600), frameAspect: 9 / 16);
      expect(mapper.displaySize.width, 400);
      expect(mapper.displaySize.height, closeTo(711.11, 0.01));
      // The frame's centre stays at the area's centre.
      final centre = mapper
          .toArea(const Rect.fromLTRB(0.4, 0.4, 0.6, 0.6))
          .center;
      expect(centre.dx, closeTo(200, 0.01));
      expect(centre.dy, closeTo(300, 0.01));
    });

    test('a taller area crops the sides of the frame', () {
      const mapper = FrameMapper(area: Size(400, 800), frameAspect: 9 / 16);
      expect(mapper.displaySize.height, 800);
      expect(mapper.displaySize.width, closeTo(450, 0.01));
      expect(mapper.offset.dx, closeTo(-25, 0.01));
    });
  });

  group('ScannerProvider', () {
    test('stabilizes the mock detector and totals the result', () async {
      final scanner = ScannerProvider(
        detector: MockDetector(seed: 3),
        minInterval: Duration.zero,
      );
      await scanner.start();
      const frame = DetectorFrame(width: 720, height: 1280);

      expect(scanner.isLive, isFalse);
      for (var i = 0; i < 4; i++) {
        await scanner.onFrame(frame);
      }

      expect(scanner.isLive, isTrue);
      expect(scanner.count, inInclusiveRange(2, 5));
      expect(scanner.totalCentavos, totalCentavos(scanner.detections));

      scanner.reset();
      expect(scanner.count, 0);
      expect(scanner.totalCentavos, 0);

      scanner.dispose();
    });

    test('ignores frames before the detector is ready', () async {
      final scanner = ScannerProvider(
        detector: MockDetector(seed: 1),
        minInterval: Duration.zero,
      );
      await scanner.onFrame(const DetectorFrame(width: 720, height: 1280));
      expect(scanner.count, 0);
      scanner.dispose();
    });
  });
}
