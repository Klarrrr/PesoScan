import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pesoscan/core/app_theme.dart';
import 'package:pesoscan/core/frame_mapper.dart';
import 'package:pesoscan/core/guidance.dart';
import 'package:pesoscan/data/help_content.dart';
import 'package:pesoscan/models/detection.dart';
import 'package:pesoscan/models/money_class.dart';
import 'package:pesoscan/providers/scanner_provider.dart';
import 'package:pesoscan/screens/scanner/detection_overlay.dart';
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
    'items cut off by the edge are counted when enough of them is visible',
    () async {
      Future<int> countWith(List<Detection> items, Rect region) async {
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

      // The top 10% of the camera picture is cropped off the screen.
      const region = Rect.fromLTRB(0, 0.1, 1, 0.9);

      expect(
        await countWith([coinAt(0.5, 0.5, 0.16)], region),
        1,
      ); // fully visible
      expect(
        await countWith([coinAt(0.5, 0.10, 0.16)], region),
        1,
      ); // half cut off
      expect(
        await countWith([coinAt(0.5, 0.03, 0.16)], region),
        0,
      ); // a 6% sliver
      expect(
        await countWith([coinAt(0.2, 0.05, 0.08)], region),
        0,
      ); // not visible
      expect(
        await countWith([
          coinAt(0.5, 0.5, 0.16),
          coinAt(0.2, 0.05, 0.08),
        ], const Rect.fromLTWH(0, 0, 1, 1)),
        2, // with the whole picture visible, both count
      );
    },
  );

  testWidgets('a label stays inside the box when the item is at the top edge', (
    tester,
  ) async {
    final money = MoneyClasses.byId(7);
    Detection at(double top) => Detection(
      money: money,
      confidence: 0.9,
      box: Rect.fromLTWH(0.4, top, 0.2, 0.1),
    );

    Future<double> labelTop(double boxTop) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                height: 500,
                child: DetectionOverlay(
                  detections: [at(boxTop)],
                  frameAspect: 300 / 500,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      return tester.getTopLeft(find.text(money.shortValue)).dy -
          tester.getTopLeft(find.byType(DetectionOverlay)).dy;
    }

    // At the top edge the label is inside the camera area...
    expect(await labelTop(0.0), greaterThanOrEqualTo(0));
    // ...and for an item in the middle it sits above the box (250 px down).
    expect(await labelTop(0.5), lessThan(250));
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
