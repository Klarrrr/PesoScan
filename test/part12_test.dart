import 'dart:ui' show Rect;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pesoscan/core/app_theme.dart';
import 'package:pesoscan/models/detection.dart';
import 'package:pesoscan/models/money_class.dart';
import 'package:pesoscan/screens/scanner/scan_result_sheet.dart';

Detection det(int classId, {double conf = 0.9, bool verified = false}) =>
    Detection(
      money: MoneyClasses.byId(classId),
      confidence: conf,
      box: const Rect.fromLTWH(0.1, 0.1, 0.1, 0.1),
      verified: verified,
    );

Future<void> openSheet(
  WidgetTester tester,
  List<Detection> items,
  void Function(ScanResultOutcome) onResult,
) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () async =>
                  onResult(await ScanResultSheet.show(context, items)),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  group('Detection verification', () {
    test('a verified item is never low confidence', () {
      final shaky = det(7, conf: 0.3);
      expect(shaky.isLowConfidence, isTrue);
      expect(shaky.level, ConfidenceLevel.low);

      final checked = shaky.copyWith(verified: true);
      expect(checked.isLowConfidence, isFalse);
      expect(checked.level, ConfidenceLevel.high);
    });

    test('levels follow the thresholds', () {
      expect(det(7, conf: 0.85).level, ConfidenceLevel.high);
      expect(det(7, conf: 0.70).level, ConfidenceLevel.medium);
      expect(det(7, conf: 0.59).level, ConfidenceLevel.low);
    });

    test('verified survives JSON', () {
      expect(
        Detection.fromJson(det(7, verified: true).toJson()).verified,
        isTrue,
      );
      expect(Detection.fromJson(det(7).toJson()).verified, isFalse);
    });
  });

  testWidgets('verify, change and remove items, then save', (tester) async {
    ScanResultOutcome? outcome;
    await openSheet(tester, [det(7, conf: 0.4), det(6)], (o) => outcome = o);

    expect(find.text('₱15.00'), findsOneWidget);
    expect(
      find.text('Some items have low confidence. Verify manually.'),
      findsOneWidget,
    );

    // Confirm the doubtful P10: the warning disappears.
    await tester.tap(find.byKey(const Key('result-row-7')));
    await tester.pumpAndSettle();
    expect(find.text('Verify items'), findsOneWidget);
    await tester.tap(find.byKey(const Key('verify-confirm-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.textContaining('low confidence'), findsNothing);

    // Change the P5 into a P1 BSP coin (class 3): total becomes 11.00.
    await tester.tap(find.byKey(const Key('result-row-6')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('verify-change-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pick-class-3')));
    await tester.pumpAndSettle();
    expect(find.text('Verify items'), findsNothing); // group emptied -> closed
    expect(find.text('₱11.00'), findsOneWidget);

    // Remove the P1 coin.
    await tester.tap(find.byKey(const Key('result-row-3')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('verify-remove-1')));
    await tester.pumpAndSettle();
    expect(find.text('1 item detected'), findsOneWidget);

    await tester.tap(find.text('Save to History'));
    await tester.pumpAndSettle();
    expect(outcome?.action, ResultAction.save);
    expect(outcome?.detections.length, 1);
    expect(outcome?.detections.first.verified, isTrue);
  });

  testWidgets('Rescan and Discard return their actions', (tester) async {
    ScanResultOutcome? outcome;
    await openSheet(tester, [det(7)], (o) => outcome = o);

    await tester.tap(find.byKey(const Key('btn-rescan')));
    await tester.pumpAndSettle();
    expect(outcome?.action, ResultAction.rescan);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(outcome?.action, ResultAction.discard);
  });
}
