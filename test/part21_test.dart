import 'dart:io';
import 'dart:ui' show Rect;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pesoscan/core/app_health.dart';
import 'package:pesoscan/core/app_theme.dart';
import 'package:pesoscan/models/detection.dart';
import 'package:pesoscan/models/money_class.dart';
import 'package:pesoscan/models/scan_record.dart';
import 'package:pesoscan/providers/auth_provider.dart';
import 'package:pesoscan/providers/history_provider.dart';
import 'package:pesoscan/providers/scanner_provider.dart';
import 'package:pesoscan/providers/settings_provider.dart';
import 'package:pesoscan/screens/scanner/problem_widgets.dart';
import 'package:pesoscan/screens/shell/main_shell.dart';
import 'package:pesoscan/services/connectivity_service.dart';
import 'package:pesoscan/services/detector/detector_factory.dart';
import 'package:pesoscan/services/detector/mock_detector.dart';
import 'package:pesoscan/services/detector/money_detector.dart';
import 'package:pesoscan/services/scan_image_store.dart';
import 'package:pesoscan/services/scan_repository.dart';
import 'package:pesoscan/services/scan_saver.dart';
import 'package:pesoscan/services/storage_errors.dart';
import 'package:pesoscan/widgets/confirm_dialog.dart';
import 'package:pesoscan/widgets/friendly_error_view.dart';
import 'package:pesoscan/widgets/offline_banner.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------- helpers

class _EmptyDetector implements MoneyDetector {
  @override
  Future<void> initialize() async {}

  @override
  Future<List<Detection>> detect(DetectorFrame frame) async => const [];

  @override
  void dispose() {}
}

/// Fails on every picture until [failing] is switched off.
class _FlakyDetector implements MoneyDetector {
  bool failing = true;

  @override
  Future<void> initialize() async {}

  @override
  Future<List<Detection>> detect(DetectorFrame frame) async {
    if (failing) throw StateError('boom');
    return const [];
  }

  @override
  void dispose() {}
}

class _BrokenDetector implements MoneyDetector {
  @override
  Future<void> initialize() async => throw StateError('cannot start');

  @override
  Future<List<Detection>> detect(DetectorFrame frame) async => const [];

  @override
  void dispose() {}
}

final _detections = [
  Detection(
    money: MoneyClasses.byId(7),
    confidence: 0.9,
    box: const Rect.fromLTWH(0.1, 0.1, 0.1, 0.1),
  ),
];

Widget _host(Widget child) => MaterialApp(
  theme: AppTheme.dark,
  home: Scaffold(
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    ),
  ),
);

void main() {
  const frame = DetectorFrame(width: 720, height: 1280);

  // ------------------------------------------------------------ storage

  group('isStorageFullError', () {
    test('recognises full-storage errors', () {
      expect(
        isStorageFullError(
          FileSystemException(
            'write failed',
            '/data/x.jpg',
            const OSError('No space left on device', 28),
          ),
        ),
        isTrue,
      );
      expect(
        isStorageFullError(
          Exception('database or disk is full (code 13 SQLITE_FULL)'),
        ),
        isTrue,
      );
    });

    test('ignores other errors', () {
      expect(isStorageFullError(StateError('boom')), isFalse);
      expect(isStorageFullError(const FileSystemException('nope')), isFalse);
    });
  });

  group('ScanSaver', () {
    late Directory root;
    late ScanImageStore images;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('pesoscan_saver');
      images = ScanImageStore(root: () async => root);
    });

    tearDown(() => root.delete(recursive: true));

    ScanSaver saverWith(Future<void> Function(ScanRecord) add) => ScanSaver(
      add: add,
      images: images,
      newId: () => 'scan-1',
      now: () => DateTime(2026, 10, 1),
    );

    test('prepare moves the photo into permanent storage', () async {
      final temp = File(p.join(root.path, 'camera_tmp.jpg'))
        ..writeAsBytesSync([1, 2, 3]);

      final pending = await saverWith((_) async {}).prepare(temp.path);

      expect(pending.photoLost, isFalse);
      expect(File(pending.imagePath).existsSync(), isTrue);
      expect(temp.existsSync(), isFalse);
    });

    test('a missing photo means saving without one', () async {
      final saver = saverWith((_) async {});
      expect((await saver.prepare(null)).photoLost, isTrue);
      expect(
        (await saver.prepare(p.join(root.path, 'does_not_exist.jpg')))
            .imagePath,
        '',
      );
    });

    test('commit reports saved, with and without a photo', () async {
      final saved = <ScanRecord>[];
      final saver = saverWith((record) async => saved.add(record));

      final temp = File(p.join(root.path, 'a.jpg'))..writeAsBytesSync([9]);
      final withPhoto = await saver.prepare(temp.path);
      expect(
        await saver.commit(withPhoto, detections: _detections, userId: 'u1'),
        SaveOutcome.saved,
      );

      final withoutPhoto = await saver.prepare(null);
      expect(
        await saver.commit(withoutPhoto, detections: _detections, userId: 'u1'),
        SaveOutcome.savedWithoutPhoto,
      );

      expect(saved.length, 2);
      expect(saved.first.userId, 'u1');
    });

    test('a full phone can be retried without losing the scan', () async {
      var full = true;
      final saved = <ScanRecord>[];
      final saver = saverWith((record) async {
        if (full) {
          throw Exception('database or disk is full (code 13 SQLITE_FULL)');
        }
        saved.add(record);
      });

      final pending = await saver.prepare(null);
      expect(
        await saver.commit(pending, detections: _detections, userId: 'u'),
        SaveOutcome.storageFull,
      );
      expect(saved, isEmpty);

      full = false; // the user freed some space
      expect(
        await saver.commit(pending, detections: _detections, userId: 'u'),
        SaveOutcome.savedWithoutPhoto,
      );
      expect(saved.single.id, 'scan-1');
    });

    test('another kind of error is reported as failed', () async {
      final saver = saverWith((_) async => throw StateError('boom'));
      final pending = await saver.prepare(null);
      expect(
        await saver.commit(pending, detections: _detections, userId: 'u'),
        SaveOutcome.failed,
      );
    });

    test('abandon removes the stored photo', () async {
      final temp = File(p.join(root.path, 'b.jpg'))..writeAsBytesSync([1]);
      final saver = saverWith((_) async {});
      final pending = await saver.prepare(temp.path);
      expect(File(pending.imagePath).existsSync(), isTrue);

      await saver.abandon(pending);
      expect(File(pending.imagePath).existsSync(), isFalse);
    });
  });

  // ------------------------------------------------------------ detector

  group('DetectorFactory', () {
    test('demo detections only when allowed', () {
      expect(DetectorFactory.create(allowDemo: true), isA<MockDetector>());
      expect(
        DetectorFactory.create(allowDemo: false),
        isA<UnavailableDetector>(),
      );
      expect(DetectorFactory.demoAllowed, isTrue); // tests run in debug mode
    });

    test('the unavailable detector refuses to start', () async {
      await expectLater(
        const UnavailableDetector().initialize(),
        throwsA(isA<ModelLoadException>()),
      );
    });
  });

  group('ScannerProvider problems', () {
    test('a missing model becomes a start-up error you can retry', () async {
      final scanner = ScannerProvider(detector: const UnavailableDetector());
      await scanner.start();

      expect(scanner.hasStartupError, isTrue);
      expect(scanner.startupError, contains('not installed'));
      expect(scanner.isReady, isFalse);
      expect(scanner.hasProblem, isTrue);

      await scanner.onFrame(frame); // ignored: not ready
      expect(scanner.count, 0);

      await scanner.retry(); // still missing
      expect(scanner.hasStartupError, isTrue);
      scanner.dispose();
    });

    test('an unexpected start-up error gets a plain message', () async {
      final scanner = ScannerProvider(detector: _BrokenDetector());
      await scanner.start();
      expect(scanner.startupError, 'The detection model could not be started.');
      scanner.dispose();
    });

    test(
      'three failed pictures in a row are a problem; retry clears it',
      () async {
        final detector = _FlakyDetector();
        final scanner = ScannerProvider(
          detector: detector,
          minInterval: Duration.zero,
        );
        await scanner.start();

        await scanner.onFrame(frame);
        await scanner.onFrame(frame);
        expect(scanner.processingFailed, isFalse);

        await scanner.onFrame(frame);
        expect(scanner.processingFailed, isTrue);
        expect(scanner.hasProblem, isTrue);

        detector.failing = false;
        await scanner.retry();
        expect(scanner.processingFailed, isFalse);

        await scanner.onFrame(frame);
        expect(scanner.processingFailed, isFalse);
        scanner.dispose();
      },
    );

    test(
      '"nothing found" appears after a wait and restarts on reset',
      () async {
        var now = DateTime(2026, 10, 1, 12);
        final scanner = ScannerProvider(
          detector: _EmptyDetector(),
          minInterval: Duration.zero,
          now: () => now,
        );
        await scanner.start();

        expect(scanner.noItemsFound, isFalse);
        now = now.add(const Duration(seconds: 7));
        expect(scanner.noItemsFound, isFalse);
        now = now.add(const Duration(seconds: 2)); // 9 seconds in total
        expect(scanner.noItemsFound, isTrue);

        scanner.reset(); // the wait starts again
        expect(scanner.noItemsFound, isFalse);
        scanner.dispose();
      },
    );

    test('finding items means nothing is "missing"', () async {
      var now = DateTime(2026, 10, 1, 12);
      final scanner = ScannerProvider(
        detector: MockDetector(seed: 3),
        minInterval: Duration.zero,
        now: () => now,
      );
      await scanner.start();
      for (var i = 0; i < 4; i++) {
        await scanner.onFrame(frame);
      }
      expect(scanner.isLive, isTrue);

      now = now.add(const Duration(minutes: 1));
      expect(scanner.noItemsFound, isFalse);
      scanner.dispose();
    });

    test('demo mode is reported for the fake detector only', () {
      final fake = ScannerProvider(detector: MockDetector(seed: 1));
      expect(fake.isDemoMode, isTrue);
      expect(fake.demoReason, isNotNull);
      fake.dispose();

      final real = ScannerProvider(detector: _EmptyDetector());
      expect(real.isDemoMode, isFalse);
      expect(real.demoReason, isNull);
      real.dispose();
    });
  });

  // ------------------------------------------------------------- widgets

  testWidgets('the problem card shows its text and Retry works', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(
        ScanProblemCard(
          icon: Icons.memory_rounded,
          title: 'Detection is not available',
          message: 'The model is missing.',
          retryLabel: 'Try again',
          onRetry: () => taps++,
        ),
      ),
    );

    expect(find.text('Detection is not available'), findsOneWidget);
    expect(find.text('The model is missing.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('btn-retry')));
    expect(taps, 1);
  });

  testWidgets('the empty card offers the scanning guide', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_host(EmptyScanCard(onHelp: () => taps++)));

    expect(find.text('No coins or bills found'), findsOneWidget);
    await tester.tap(find.byKey(const Key('btn-empty-help')));
    expect(taps, 1);
  });

  testWidgets('the demo badge says it is a demo', (tester) async {
    await tester.pumpWidget(_host(const DemoBadge(reason: 'Fake detections')));
    expect(find.textContaining('DEMO MODE'), findsOneWidget);
  });

  testWidgets('the offline banner follows the connection', (tester) async {
    final service = ConnectivityService.forTesting(online: true);
    await tester.pumpWidget(_host(OfflineBanner(service: service)));
    expect(find.byKey(const Key('offline-banner')), findsNothing);

    service.setOnline(false);
    await tester.pump();
    expect(find.byKey(const Key('offline-banner')), findsOneWidget);

    service.setOnline(true);
    await tester.pump();
    expect(find.byKey(const Key('offline-banner')), findsNothing);
  });

  testWidgets('the friendly error view shows a calm message', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: FriendlyErrorView()));
    expect(find.text('Something went wrong'), findsOneWidget);
  });

  testWidgets('a one-button message dialog', (tester) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () async => result = await ConfirmDialog.show(
                  context,
                  icon: Icons.info_outline,
                  title: 'Heads up',
                  message: 'Something to read.',
                  confirmLabel: 'Got it',
                  showCancel: false,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Heads up'), findsOneWidget);
    expect(find.text('Cancel'), findsNothing);

    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('a custom cancel label is used', (tester) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () async => result = await ConfirmDialog.show(
                  context,
                  icon: Icons.sd_storage_outlined,
                  title: 'Storage space is full',
                  message: 'Free some space.',
                  confirmLabel: 'Try again',
                  cancelLabel: 'Discard scan',
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Cancel'), findsNothing);

    await tester.tap(find.text('Discard scan'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });

  // The phones this app targets are 6.1 to 6.9 inches: about 360 to 448 dp
  // wide. Check the new widgets on those sizes, also with big system text.
  for (final size in const [Size(360, 780), Size(411, 914), Size(448, 997)]) {
    for (final scale in const [1.0, 1.3]) {
      testWidgets(
        'new widgets fit ${size.width.toInt()}x${size.height.toInt()} '
        'with text at ${scale}x',
        (tester) async {
          tester.view.physicalSize = size * 2.75;
          tester.view.devicePixelRatio = 2.75;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

          await tester.pumpWidget(
            _host(
              Column(
                children: [
                  ScanProblemCard(
                    icon: Icons.image_not_supported_outlined,
                    title: 'Unable to process the picture',
                    message:
                        'Something went wrong while reading the camera '
                        'picture. Try again, or restart the app if it keeps '
                        'happening.',
                    retryLabel: 'Try again',
                    onRetry: () {},
                  ),
                  const SizedBox(height: 12),
                  EmptyScanCard(onHelp: () {}),
                  const SizedBox(height: 12),
                  const DemoBadge(reason: 'Fake detections for testing'),
                  const SizedBox(height: 12),
                  OfflineBanner(
                    service: ConnectivityService.forTesting(online: false),
                  ),
                ],
              ),
            ),
          );
          await tester.pump();

          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  // --------------------------------------------------------- main shell

  testWidgets('a broken database shows a one-time warning', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    AppHealth.reset();
    AppHealth.databaseFailed = true;
    addTearDown(AppHealth.reset);

    SharedPreferences.setMockInitialValues({});
    final settings = SettingsProvider();
    await settings.load();
    final auth = AuthProvider();
    final history = HistoryProvider(InMemoryScanRepository(), auth);
    await history.load();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider.value(value: history),
          ChangeNotifierProvider.value(value: auth),
        ],
        child: MaterialApp(theme: AppTheme.dark, home: const MainShell()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Scan history cannot be saved'), findsOneWidget);
    expect(AppHealth.warningShown, isTrue);

    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    expect(find.text('Scan history cannot be saved'), findsNothing);
  });
}
