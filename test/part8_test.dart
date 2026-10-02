import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pesoscan/core/app_theme.dart';
import 'package:pesoscan/core/time_labels.dart';
import 'package:pesoscan/providers/auth_provider.dart';
import 'package:pesoscan/providers/history_provider.dart';
import 'package:pesoscan/providers/settings_provider.dart';
import 'package:pesoscan/screens/shell/main_shell.dart';
import 'package:pesoscan/services/sample_data.dart';
import 'package:pesoscan/services/scan_repository.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('time labels', () {
    final now = DateTime(2026, 10, 1, 15);
    expect(
      scanTimeLabel(DateTime(2026, 10, 1, 9, 55), now: now),
      isNot(contains('Yesterday')),
    );
    expect(
      scanTimeLabel(DateTime(2026, 9, 30, 9, 55), now: now),
      startsWith('Yesterday, '),
    );
    expect(
      scanTimeLabel(DateTime(2026, 9, 25, 9, 55), now: now),
      startsWith('Sep 25, '),
    );
  });
  test('sample scans compute their totals from the coins', () {
    final scans = sampleScans(now: DateTime(2026, 10, 1));
    expect(scans.length, 4);
    // 10 + 10 + 5 + 5 + 1 + 1 + 0.05 = 32.05
    expect(scans.first.totalCentavos, 3205);
  });

  testWidgets('home shows the card, tiles and recent scans; tabs switch', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final settings = SettingsProvider();
    await settings.load();
    final auth = AuthProvider();
    final history = HistoryProvider(
      InMemoryScanRepository(seed: sampleScans()),
      auth,
    );
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

    expect(find.text('Start Scanning'), findsOneWidget);
    expect(find.text('Currency Guide'), findsOneWidget);
    expect(find.text('Statistics'), findsOneWidget);
    expect(find.text('Recent Scans'), findsOneWidget);
    expect(find.textContaining('items detected'), findsWidgets);
    expect(find.text('4 sessions'), findsOneWidget);

    // History tab is a placeholder for now.
    await tester.tap(find.byKey(const Key('nav-history')));
    await tester.pumpAndSettle();
    expect(find.text('Coming soon'), findsOneWidget);
    expect(find.text('Start Scanning'), findsNothing);
  });
}
