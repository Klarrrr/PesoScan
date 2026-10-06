import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pesoscan/core/app_theme.dart';
import 'package:pesoscan/core/format_bytes.dart';
import 'package:pesoscan/models/detection.dart';
import 'package:pesoscan/models/money_class.dart';
import 'package:pesoscan/models/scan_record.dart';
import 'package:pesoscan/providers/auth_provider.dart';
import 'package:pesoscan/providers/history_provider.dart';
import 'package:pesoscan/providers/settings_provider.dart';
import 'package:pesoscan/screens/settings/settings_tab.dart';
import 'package:pesoscan/services/scan_repository.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

ScanRecord scanWithPhoto(String id, String photoPath) => ScanRecord(
  id: id,
  createdAt: DateTime(2026, 10, 1),
  imagePath: photoPath,
  detections: [
    Detection(
      money: MoneyClasses.byId(7),
      confidence: 0.9,
      box: const Rect.fromLTWH(0.1, 0.1, 0.1, 0.1),
    ),
  ],
);

void main() {
  test('formatBytes', () {
    expect(formatBytes(0), '0 B');
    expect(formatBytes(512), '512 B');
    expect(formatBytes(1536), '1.5 KB');
    expect(formatBytes(5 * 1024 * 1024), '5.0 MB');
    expect(formatBytes(3 * 1024 * 1024 * 1024), '3.0 GB');
  });

  group('clearing photos', () {
    test('deletes the files but keeps the scans', () async {
      final folder = await Directory.systemTemp.createTemp('pesoscan_photos');
      addTearDown(() => folder.delete(recursive: true));

      final photo = File(p.join(folder.path, 'a.jpg'))
        ..writeAsBytesSync(List.filled(100, 1));
      final history = HistoryProvider(
        InMemoryScanRepository(
          seed: [
            scanWithPhoto('a', photo.path),
            scanWithPhoto('b', ''), // a scan that never had a photo
          ],
        ),
        AuthProvider(),
      );
      await history.load();

      final before = await history.photoStats();
      expect(before.count, 1);
      expect(before.bytes, 100);

      final freed = await history.clearPhotos();

      expect(freed, 100);
      expect(photo.existsSync(), isFalse);
      expect(history.count, 2); // both scans are still there
      expect(history.all.every((s) => s.imagePath.isEmpty), isTrue);
      expect((await history.photoStats()).count, 0);
    });
  });

  group('SettingsTab', () {
    Future<(SettingsProvider, HistoryProvider)> pumpSettings(
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 12000); // was 4200
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);

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
            ChangeNotifierProvider.value(value: auth),
            ChangeNotifierProvider.value(value: history),
          ],
          child: MaterialApp(
            theme: AppTheme.dark,
            home: const Scaffold(body: SettingsTab()),
          ),
        ),
      );
      return (settings, history);
    }

    testWidgets('shows every section of the prototype', (tester) async {
      await pumpSettings(tester);

      for (final label in [
        'ACCOUNT',
        'DISPLAY & THEME',
        'HAPTIC & AUDIO FEEDBACK',
        'STORAGE',
        'SUPPORT',
        'ABOUT & LEGAL',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('Dark Mode'), findsOneWidget);
      expect(find.text('Audio Chime'), findsOneWidget);
      expect(find.text('Clear Cached Images'), findsOneWidget);
      expect(find.text('19 supported classes'), findsOneWidget);
      expect(find.text('Terms of Service'), findsOneWidget);
      expect(find.text('Exit App'), findsOneWidget);
    });

    testWidgets('theme rows and switches change the settings', (tester) async {
      final (settings, _) = await pumpSettings(tester);
      expect(settings.themeMode, ThemeMode.dark);

      await tester.tap(find.byKey(const Key('theme-light')));
      await tester.pump();
      expect(settings.themeMode, ThemeMode.light);

      await tester.tap(find.byKey(const Key('switch-haptic')));
      await tester.pump();
      expect(settings.hapticEnabled, isFalse);

      // Turn audio OFF (turning it on would play a sound).
      await tester.tap(find.byKey(const Key('switch-audio')));
      await tester.pump();
      expect(settings.audioEnabled, isFalse);
    });

    testWidgets('Exit App and Log Out ask first and can be cancelled', (
      tester,
    ) async {
      await pumpSettings(tester);

      await tester.tap(find.byKey(const Key('tile-exit')));
      await tester.pumpAndSettle();
      expect(find.text('Exit PesoScan?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Exit PesoScan?'), findsNothing);

      await tester.tap(find.byKey(const Key('tile-logout')));
      await tester.pumpAndSettle();
      expect(find.text('Log out?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Log out?'), findsNothing);
    });

    testWidgets('clearing photos with nothing to clear says so', (
      tester,
    ) async {
      await pumpSettings(tester);

      await tester.tap(find.byKey(const Key('tile-clear-cache')));
      await tester.pumpAndSettle();
      expect(find.text('No saved photos to clear.'), findsOneWidget);
    });
  });
}
