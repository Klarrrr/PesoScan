import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pesoscan/core/app_theme.dart';
import 'package:pesoscan/models/detection.dart';
import 'package:pesoscan/models/money_class.dart';
import 'package:pesoscan/models/scan_record.dart';
import 'package:pesoscan/screens/history/scan_detail_screen.dart';
import 'package:pesoscan/services/scan_exporter.dart';

/// Records what the app asked the phone to do.
class FakeActions implements ExportActions {
  final calls = <String>[];
  Uint8List? lastPng;
  String? lastFile;
  String? lastText;
  Object? failWith;

  void _check() {
    if (failWith != null) throw failWith!;
  }

  @override
  Future<void> shareImage({
    required Uint8List png,
    required String fileName,
    required String text,
  }) async {
    _check();
    calls.add('share');
    lastPng = png;
    lastFile = fileName;
    lastText = text;
  }

  @override
  Future<void> saveToGallery({
    required Uint8List png,
    required String fileName,
  }) async {
    _check();
    calls.add('save');
    lastPng = png;
    lastFile = fileName;
  }

  @override
  Future<void> copyText(String text) async {
    _check();
    calls.add('copy');
    lastText = text;
  }
}

final record = ScanRecord(
  id: 'x',
  createdAt: DateTime(2026, 9, 30, 10, 18),
  imagePath: '',
  detections: [
    for (final id in [7, 7, 6])
      Detection(
        money: MoneyClasses.byId(id),
        confidence: 0.9,
        box: const Rect.fromLTWH(0.1, 0.1, 0.1, 0.1),
      ),
  ],
); // P10 + P10 + P5 = P25.00

ScanExporter exporterWith(FakeActions actions, {CaptureFn? capture}) =>
    ScanExporter(
      capture: capture ?? (_) async => Uint8List.fromList([1, 2, 3]),
      actions: actions,
    );

void main() {
  group('ScanExporter', () {
    test('share sends the picture, a good file name and the total', () async {
      final actions = FakeActions();
      final outcome = await exporterWith(actions).share(GlobalKey(), record);

      expect(outcome.ok, isTrue);
      expect(actions.calls, ['share']);
      expect(actions.lastPng, [1, 2, 3]);
      expect(actions.lastFile, 'pesoscan_20260930_101800.png');
      expect(actions.lastText, contains('₱25.00'));
    });

    test('save puts the picture in the gallery', () async {
      final actions = FakeActions();
      final outcome = await exporterWith(actions)
          .saveToDevice(GlobalKey(), record);

      expect(outcome.ok, isTrue);
      expect(outcome.message, contains('gallery'));
      expect(actions.calls, ['save']);
    });

    test('copy puts the formatted total on the clipboard', () async {
      final actions = FakeActions();
      final outcome = await exporterWith(actions).copyTotal(record);

      expect(actions.calls, ['copy']);
      expect(actions.lastText, '₱25.00');
      expect(outcome.message, 'Total ₱25.00 copied.');
    });

    test('a known problem is reported with its own message', () async {
      final actions = FakeActions()
        ..failWith = const ExportException('Your phone is almost full.');
      final outcome = await exporterWith(actions)
          .saveToDevice(GlobalKey(), record);

      expect(outcome.ok, isFalse);
      expect(outcome.message, 'Your phone is almost full.');
    });

    test('an unexpected error becomes a friendly message', () async {
      final actions = FakeActions()..failWith = StateError('boom');
      final outcome = await exporterWith(actions).copyTotal(record);

      expect(outcome.ok, isFalse);
      expect(outcome.message, 'Something went wrong. Please try again.');
    });

    test('a failed capture stops before anything is shared', () async {
      final actions = FakeActions();
      final exporter = exporterWith(
        actions,
        capture: (_) async => throw const ExportException('not ready'),
      );
      final outcome = await exporter.share(GlobalKey(), record);

      expect(outcome.message, 'not ready');
      expect(actions.calls, isEmpty);
    });
  });

  testWidgets('captureBoundaryPng makes a real PNG', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: RepaintBoundary(
            key: key,
            child: Container(width: 40, height: 40, color: Colors.red),
          ),
        ),
      ),
    );

    // The engine needs real time to draw, so leave the fake clock for a moment.
    final bytes = await tester.runAsync(() => captureBoundaryPng(key));

    expect(bytes, isNotNull);
    expect(bytes!.sublist(0, 4), [
      137,
      80,
      78,
      71,
    ]); // every PNG starts like this
  });

  group('Scan Detail buttons', () {
    Future<FakeActions> pumpDetail(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2600);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);

      final actions = FakeActions();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: ScanDetailScreen(
            record: record,
            exporter: exporterWith(actions),
          ),
        ),
      );
      return actions;
    }

    Future<void> tapButton(WidgetTester tester, String key) async {
      final finder = find.byKey(Key(key));
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    testWidgets('Copy total copies and tells the user', (tester) async {
      final actions = await pumpDetail(tester);
      await tapButton(tester, 'btn-copy');

      expect(actions.calls, ['copy']);
      expect(find.text('Total ₱25.00 copied.'), findsOneWidget);
    });

    testWidgets('Save and Share call the exporter', (tester) async {
      final actions = await pumpDetail(tester);
      await tapButton(tester, 'btn-save');
      await tapButton(tester, 'btn-share');

      expect(actions.calls, ['save', 'share']);
    });

    testWidgets('a failure is shown in a snackbar', (tester) async {
      final actions = await pumpDetail(tester);
      actions.failWith = const ExportException(
        'Allow photo access in Settings to save pictures.',
      );
      await tapButton(tester, 'btn-save');

      expect(
        find.text('Allow photo access in Settings to save pictures.'),
        findsOneWidget,
      );
    });
  });
}
