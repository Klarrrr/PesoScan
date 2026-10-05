import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pesoscan/core/frame_mapper.dart';
import 'package:pesoscan/core/guidance.dart';
import 'package:pesoscan/data/help_content.dart';
import 'package:pesoscan/models/detection.dart';
import 'package:pesoscan/models/money_class.dart';
import 'package:pesoscan/providers/scanner_provider.dart';
import 'package:pesoscan/services/detector/money_detector.dart';

class _FixedDetector implements MoneyDetector {
  final List<Detection> items;
  _FixedDetector(this.items);

  @override
  Future<void> initialize() async {}

  @override
  Future<List<Detection>> detect(DetectorFrame frame) async => items;

  @override
  void dispose() {}
}

Detection coinAt(double cx, double cy, double size) => Detection(
  money: MoneyClasses.byId(7),
  confidence: 0.9,
  box: Rect.fromCenter(center: Offset(cx, cy), width: size, height: size),
);

void main() {
  const frame = DetectorFrame(width: 720, height: 1280);

  group('FrameMapper.visibleFrameRect', () {
    test('a wider area crops the top and bottom of the picture', () {
      const mapper = FrameMapper(area: Size(400, 600), frameAspect: 9 / 16);
      final r = mapper.visibleFrameRect;
      expect(r.left, 0);
      expect(r.right, 1);
      expect(r.top, closeTo(0.078125, 0.0001));
      expect(r.bottom, closeTo(0.921875, 0.0001));
    });

    test('a taller area crops the sides', () {
      const mapper = FrameMapper(area: Size(400, 800), frameAspect: 9 / 16);
      final r = mapper.visibleFrameRect;
      expect(r.left, closeTo(0.05556, 0.0001));
      expect(r.right, closeTo(0.94444, 0.0001));
      expect(r.top, 0);
      expect(r.bottom, 1);
    });

    test('an area with the same shape shows everything', () {
      const mapper = FrameMapper(area: Size(450, 800), frameAspect: 9 / 16);
      final r = mapper.visibleFrameRect;
      expect([
        r.left,
        r.top,
        r.right,
        r.bottom,
      ], everyElement(anyOf(closeTo(0, 0.0001), closeTo(1, 0.0001))));
    });
  });

  test(
    'only items inside the visible part of the picture are counted',
    () async {
      final items = [coinAt(0.5, 0.5, 0.16), coinAt(0.2, 0.05, 0.08)];

      Future<int> countWith(Rect region) async {
        final scanner = ScannerProvider(
          detector: _FixedDetector(items),
          minInterval: Duration.zero,
        );
        scanner.visibleRegion = region;
        await scanner.start();
        for (var i = 0; i < 4; i++) {
          await scanner.onFrame(frame);
        }
        final count = scanner.count;
        scanner.dispose();
        return count;
      }

      // The whole picture is visible: both are counted.
      expect(await countWith(const Rect.fromLTWH(0, 0, 1, 1)), 2);
      // The top 10% is cropped off: the item up there is not counted.
      expect(await countWith(const Rect.fromLTRB(0, 0.1, 1, 0.9)), 1);
    },
  );

  test('"cut off at the edge" is measured against what is visible', () {
    final item = coinAt(0.5, 0.12, 0.08); // its top edge is at 0.08

    expect(
      evaluateGuidance(detections: [item]),
      isNot(contains(GuidanceTip.itemsOutsideFrame)),
    );
    expect(
      evaluateGuidance(
        detections: [item],
        visible: const Rect.fromLTRB(0, 0.1, 1, 0.9),
      ),
      contains(GuidanceTip.itemsOutsideFrame),
    );
  });

  test(
    'tips and help no longer mention cm, 5 mm, overlap rules or the corners',
    () {
      final tipText = GuidanceTip.values
          .map((t) => '${t.title} ${t.message}')
          .join(' ');
      final helpText = [
        ...quickTips,
        for (final s in faqItems()) '${s.title} ${s.body}',
      ].join(' ');

      for (final text in [tipText, helpText]) {
        final lower = text.toLowerCase();
        for (final banned in [
          'gold corners',
          ' cm',
          '5 mm',
          'no overlapping',
        ]) {
          expect(lower, isNot(contains(banned)), reason: 'found "$banned"');
        }
      }
    },
  );
}
