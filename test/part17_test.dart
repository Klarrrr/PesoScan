// ignore_for_file: unused_import

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pesoscan/core/app_theme.dart';
import 'package:pesoscan/core/guidance.dart';
import 'package:pesoscan/models/detection.dart';
import 'package:pesoscan/models/money_class.dart';
import 'package:pesoscan/providers/scanner_provider.dart';
import 'package:pesoscan/screens/scanner/guidance_widgets.dart';
import 'package:pesoscan/services/detector/mock_detector.dart';
import 'package:pesoscan/services/detector/money_detector.dart';
import 'package:pesoscan/services/frame_analyzer.dart';

Detection coin(Rect box, {int classId = 7}) =>
    Detection(money: MoneyClasses.byId(classId), confidence: 0.9, box: box);

Rect around(double cx, double cy, double size) =>
    Rect.fromCenter(center: Offset(cx, cy), width: size, height: size);

void main() {
  const frame = DetectorFrame(width: 720, height: 1280);

  group('evaluateGuidance', () {
    test('light and shaking come from the signals', () {
      expect(
        evaluateGuidance(
          detections: [],
          signals: const FrameSignals(brightness: 20, motion: 0),
        ),
        {GuidanceTip.tooDark},
      );
      expect(
        evaluateGuidance(
          detections: [],
          signals: const FrameSignals(brightness: 240, motion: 0),
        ),
        {GuidanceTip.tooBright},
      );
      expect(
        evaluateGuidance(
          detections: [],
          signals: const FrameSignals(brightness: 120, motion: 40),
        ),
        {GuidanceTip.shaky},
      );
      expect(
        evaluateGuidance(
          detections: [],
          signals: const FrameSignals(brightness: 120, motion: 2),
        ),
        isEmpty,
      );
    });

    test(
      'heavy overlap is flagged; small overlap and near-touching are not',
      () {
        // One coin almost on top of another.
        final heavy = [
          coin(around(0.45, 0.45, 0.16)),
          coin(around(0.48, 0.46, 0.16)),
        ];
        expect(
          evaluateGuidance(detections: heavy),
          contains(GuidanceTip.itemsTooClose),
        );

        // Edges overlapping a little: fine, the model handles it.
        final slight = [
          coin(around(0.40, 0.45, 0.16)),
          coin(around(0.50, 0.47, 0.16)),
        ];
        expect(
          evaluateGuidance(detections: slight),
          isNot(contains(GuidanceTip.itemsTooClose)),
        );

        // Close together but not touching.
        final near = [
          coin(around(0.25, 0.30, 0.15)),
          coin(around(0.45, 0.30, 0.15)),
        ];
        expect(
          evaluateGuidance(detections: near),
          isNot(contains(GuidanceTip.itemsTooClose)),
        );
      },
    );

    test('an item touching the picture edge is NOT a problem', () {
      expect(
        evaluateGuidance(detections: [coin(around(0.95, 0.5, 0.16))]),
        isEmpty,
      );
    });

    test('very small items say "closer", very large ones say "back"', () {
      expect(
        evaluateGuidance(detections: [coin(around(0.5, 0.5, 0.03))]),
        contains(GuidanceTip.moveCloser),
      );
      expect(
        evaluateGuidance(detections: [coin(around(0.5, 0.5, 0.6))]),
        contains(GuidanceTip.moveBack),
      );
      expect(
        evaluateGuidance(detections: [coin(around(0.5, 0.5, 0.16))]),
        isNot(
          anyOf(
            contains(GuidanceTip.moveCloser),
            contains(GuidanceTip.moveBack),
          ),
        ),
      );
    });

    test('an item cut off by the edge does not trigger distance advice', () {
      // It looks small only because the edge cuts it.
      final cut = coin(const Rect.fromLTRB(0.97, 0.4, 1.0, 0.5));
      expect(evaluateGuidance(detections: [cut]), isEmpty);
    });
  });

  group('GuidanceTracker', () {
    test('a tip appears after a while and leaves after a while', () {
      var now = DateTime(2026, 10, 1, 12);
      final tracker = GuidanceTracker(
        showAfter: const Duration(milliseconds: 600),
        hideAfter: const Duration(milliseconds: 800),
        now: () => now,
      );

      expect(tracker.update({GuidanceTip.tooDark}), isEmpty); // too soon
      now = now.add(const Duration(milliseconds: 700));
      expect(tracker.update({GuidanceTip.tooDark}), {GuidanceTip.tooDark});

      now = now.add(const Duration(milliseconds: 300));
      expect(tracker.update(<GuidanceTip>{}), {
        GuidanceTip.tooDark,
      }); // still shown

      now = now.add(const Duration(milliseconds: 900));
      expect(tracker.update(<GuidanceTip>{}), isEmpty); // gone
    });

    test('a short flicker never shows', () {
      var now = DateTime(2026, 10, 1, 12);
      final tracker = GuidanceTracker(now: () => now);

      tracker.update({GuidanceTip.shaky});
      now = now.add(const Duration(milliseconds: 200));
      tracker.update(<GuidanceTip>{});
      now = now.add(const Duration(milliseconds: 200));
      tracker.update({GuidanceTip.shaky});
      now = now.add(const Duration(milliseconds: 500));
      expect(
        tracker.update({GuidanceTip.shaky}),
        isEmpty,
      ); // only 500 ms in a row
    });
  });

  group('FrameAnalyzer', () {
    Uint8List flat(int value) =>
        Uint8List.fromList(List.filled(48 * 64, value));

    FrameSignals look(FrameAnalyzer a, Uint8List bytes) =>
        a.analyze(bytes: bytes, width: 48, height: 64, rowStride: 48);

    test('measures brightness', () {
      final analyzer = FrameAnalyzer();
      expect(look(analyzer, flat(30)).brightness, closeTo(30, 0.01));
    });

    test('a still picture has no motion; a changing one does', () {
      final analyzer = FrameAnalyzer();
      look(analyzer, flat(30));
      expect(look(analyzer, flat(30)).motion, 0);

      final changed = look(analyzer, flat(230));
      expect(changed.motion, greaterThan(50));
      expect(
        changed.brightness,
        closeTo(130, 0.01),
      ); // smoothed: (30 + 230) / 2
    });

    test('reset forgets the past', () {
      final analyzer = FrameAnalyzer();
      look(analyzer, flat(30));
      analyzer.reset();
      expect(look(analyzer, flat(200)).brightness, closeTo(200, 0.01));
    });
  });

  group('fake detector scenes', () {
    Future<List<Detection>> sceneOf(MockScenario scenario) async {
      final mock = MockDetector(seed: 1, scenario: scenario);
      await mock.initialize();
      return mock.detect(frame);
    }

    test('crowded scene triggers "too close"', () async {
      final tips = evaluateGuidance(
        detections: await sceneOf(MockScenario.crowded),
      );
      expect(tips, contains(GuidanceTip.itemsTooClose));
    });

    test('edge scene: items cut off by the edge are not a problem', () async {
      final items = await sceneOf(MockScenario.edge);
      expect(items.length, 3);
      expect(evaluateGuidance(detections: items), isEmpty);
    });

    test('normal scenes never trigger a warning', () async {
      final mock = MockDetector(seed: 7);
      await mock.initialize();
      for (var i = 0; i < 25; i++) {
        mock.regenerate();
        final tips = evaluateGuidance(detections: await mock.detect(frame));
        expect(tips, isEmpty, reason: 'scene $i produced $tips');
      }
    });
  });

  test('ScannerProvider turns signals into tips and clears them on reset', () {
    final scanner = ScannerProvider(
      detector: MockDetector(seed: 1),
      guidanceTracker: GuidanceTracker(
        showAfter: Duration.zero,
        hideAfter: Duration.zero,
      ),
    );

    expect(scanner.tips, isEmpty);
    scanner.updateSignals(const FrameSignals(brightness: 10, motion: 0));
    expect(scanner.tips, [GuidanceTip.tooDark]);
    expect(scanner.signals?.brightness, 10);

    scanner.reset();
    expect(scanner.tips, isEmpty);
    scanner.dispose();
  });

  group('widgets', () {
    Widget host(Widget child) => MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(body: child),
    );

    testWidgets('the banner shows the tip and a working Flash button', (
      tester,
    ) async {
      var flashTaps = 0;
      await tester.pumpWidget(
        host(
          GuidanceBanner(
            tips: const [GuidanceTip.tooDark],
            torchOn: false,
            onTurnOnFlash: () => flashTaps++,
          ),
        ),
      );

      expect(find.text('Too dark'), findsOneWidget);
      expect(find.textContaining('Turn on the flash'), findsOneWidget);
      await tester.tap(find.byKey(const Key('btn-tip-flash')));
      expect(flashTaps, 1);
    });

    testWidgets('no Flash button when the torch is already on', (tester) async {
      await tester.pumpWidget(
        host(
          GuidanceBanner(
            tips: const [GuidanceTip.tooDark],
            torchOn: true,
            onTurnOnFlash: () {},
          ),
        ),
      );
      expect(find.byKey(const Key('btn-tip-flash')), findsNothing);
    });

    testWidgets('the strip shows the three indicators', (tester) async {
      await tester.pumpWidget(
        host(
          ScanStatusStrip(
            signals: const FrameSignals(brightness: 120, motion: 1),
            tips: const [GuidanceTip.shaky],
            onHelp: () {},
          ),
        ),
      );

      expect(find.text('Light OK'), findsOneWidget);
      expect(find.text('Shaking'), findsOneWidget);
      expect(find.text('Distance'), findsOneWidget);
    });

    testWidgets('the help button opens the scanning guide', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Builder(
              builder: (context) => ScanStatusStrip(
                signals: null,
                tips: const [],
                onHelp: () => ScanGuideSheet.show(context),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('btn-guide')));
      await tester.pumpAndSettle();
      expect(find.text('How to scan well'), findsOneWidget);
      expect(find.text('Spread the items out'), findsOneWidget);
    });
  });
}
