// ignore_for_file: unnecessary_import

import 'dart:ui' show Rect;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pesoscan/core/app_theme.dart';
import 'package:pesoscan/models/detection.dart';
import 'package:pesoscan/models/money_class.dart';
import 'package:pesoscan/providers/scanner_provider.dart';
import 'package:pesoscan/screens/scanner/scan_result_sheet.dart';
import 'package:pesoscan/services/detector/mock_detector.dart';
import 'package:pesoscan/services/detector/money_detector.dart';
import 'package:pesoscan/services/feedback_service.dart';
import 'package:pesoscan/services/scan_image_store.dart';

Detection det(int classId, {double conf = 0.9}) => Detection(
  money: MoneyClasses.byId(classId),
  confidence: conf,
  box: const Rect.fromLTWH(0.1, 0.1, 0.1, 0.1),
);

void main() {
  group('chime', () {
    test('is a valid WAV file', () {
      final wav = buildChimeWav();
      expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
      final header = ByteData.sublistView(wav);
      expect(header.getUint32(24, Endian.little), 22050); // sample rate
      expect(header.getUint32(40, Endian.little), wav.length - 44); // data size
    });
  });

  group('ScanImageStore', () {
    test(
      'moves the temporary photo into scans/ and removes the original',
      () async {
        final root = await Directory.systemTemp.createTemp('pesoscan_test');
        addTearDown(() => root.delete(recursive: true));

        final temp = File(p.join(root.path, 'camera_tmp.jpg'))
          ..writeAsBytesSync([1, 2, 3]);
        final store = ScanImageStore(root: () async => root);

        final saved = await store.save(tempPath: temp.path, scanId: 'abc');

        expect(p.basename(saved), 'abc.jpg');
        expect(p.basename(p.dirname(saved)), 'scans');
        expect(File(saved).readAsBytesSync(), [1, 2, 3]);
        expect(temp.existsSync(), isFalse);
      },
    );

    test('delete is safe with null or missing files', () async {
      final store = ScanImageStore(root: () async => Directory.systemTemp);
      await store.delete(null);
      await store.delete('/definitely/not/here.jpg');
    });
  });

  group('ScannerProvider freeze', () {
    const frame = DetectorFrame(width: 720, height: 1280);

    test(
      'freeze keeps the result and ignores new frames; resume clears',
      () async {
        final scanner = ScannerProvider(
          detector: MockDetector(seed: 3),
          minInterval: Duration.zero,
        );
        await scanner.start();
        for (var i = 0; i < 4; i++) {
          await scanner.onFrame(frame);
        }

        final frozen = scanner.freeze();
        final totalWhenFrozen = scanner.totalCentavos;
        expect(scanner.isFrozen, isTrue);
        expect(frozen, isNotEmpty);

        scanner.reset(); // would change the scene...
        scanner.resume();
        expect(scanner.isFrozen, isFalse);
        expect(scanner.count, 0);
        expect(frozen.length, greaterThan(0)); // the snapshot is untouched
        expect(totalWhenFrozen, greaterThan(0));

        scanner.dispose();
      },
    );

    test('frames are ignored while frozen', () async {
      final scanner = ScannerProvider(
        detector: MockDetector(seed: 3),
        minInterval: Duration.zero,
      );
      await scanner.start();
      for (var i = 0; i < 4; i++) {
        await scanner.onFrame(frame);
      }
      scanner.freeze();
      final before = scanner.totalCentavos;
      for (var i = 0; i < 3; i++) {
        await scanner.onFrame(frame);
      }
      expect(scanner.totalCentavos, before);
      scanner.dispose();
    });

    test('onItemsLocked reports newly confirmed items', () async {
      final scanner = ScannerProvider(
        detector: MockDetector(seed: 3),
        minInterval: Duration.zero,
      );
      var added = 0;
      scanner.onItemsLocked = (n) => added += n;

      await scanner.start();
      for (var i = 0; i < 4; i++) {
        await scanner.onFrame(frame);
      }

      expect(added, greaterThan(0));
      expect(added, scanner.count);
      scanner.dispose();
    });
  });

  group('ScanResultSheet', () {
    Future<ScanResultOutcome?> openSheet(
      WidgetTester tester,
      List<Detection> detections,
      String buttonToTap,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);

      ScanResultOutcome? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () async =>
                      result = await ScanResultSheet.show(context, detections),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('groups the items, shows the total and the warning', (
      tester,
    ) async {
      await openSheet(tester, [
        det(7),
        det(7),
        det(6),
        det(1, conf: 0.4),
      ], 'Save to History');

      expect(find.text('Scan Result'), findsOneWidget);
      expect(find.text('4 items detected'), findsOneWidget);
      expect(find.text('₱25.05'), findsOneWidget); // 10 + 10 + 5 + 0.05
      expect(find.byKey(const Key('result-row-7')), findsOneWidget);
      expect(find.text('2×'), findsOneWidget);
      expect(find.text('₱20.00'), findsOneWidget);
      expect(
        find.text('Some items have low confidence. Verify manually.'),
        findsOneWidget,
      );
    });

    testWidgets('no warning when every item is confident', (tester) async {
      await openSheet(tester, [det(7), det(6)], 'Save to History');
      expect(find.textContaining('low confidence'), findsNothing);
    });

    testWidgets('Save and Discard return their actions', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);

      ScanResultOutcome? result;
      Future<void> pumpAndOpen() async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark,
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: ElevatedButton(
                    onPressed: () async =>
                        result = await ScanResultSheet.show(context, [det(7)]),
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

      await pumpAndOpen();
      await tester.tap(find.text('Save to History'));
      await tester.pumpAndSettle();
      expect(result?.action, ResultAction.save);

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(result?.action, ResultAction.discard);
    });
  });
}
