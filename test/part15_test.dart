import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pesoscan/core/app_theme.dart';
import 'package:pesoscan/core/scan_stats.dart';
import 'package:pesoscan/models/detection.dart';
import 'package:pesoscan/models/money_class.dart';
import 'package:pesoscan/models/scan_record.dart';
import 'package:pesoscan/providers/auth_provider.dart';
import 'package:pesoscan/providers/history_provider.dart';
import 'package:pesoscan/screens/stats/statistics_screen.dart';
import 'package:pesoscan/services/scan_repository.dart';
import 'package:provider/provider.dart';

ScanRecord scan(String id, List<int> classIds) => ScanRecord(
  id: id,
  createdAt: DateTime(2026, 10, 1),
  imagePath: '',
  detections: [
    for (final classId in classIds)
      Detection(
        money: MoneyClasses.byId(classId),
        confidence: 0.9,
        box: const Rect.fromLTWH(0.1, 0.1, 0.1, 0.1),
      ),
  ],
);

void main() {
  group('computeStats', () {
    test('adds everything up', () {
      // scan a: P10 + P10 = 20.00   scan b: P10 + P100 = 110.00
      final stats = computeStats([
        scan('a', [7, 7]),
        scan('b', [7, 12]),
      ]);

      expect(stats.sessions, 2);
      expect(stats.items, 4);
      expect(stats.totalCentavos, 13000);
      expect(stats.averageCentavos, 6500);
      expect(stats.byDenomination.first.valueCentavos, 1000); // P10, 3 times
      expect(stats.byDenomination.first.count, 3);
      expect(stats.byDenomination.last.valueCentavos, 10000); // P100, once
    });

    test('merges designs with the same value', () {
      // class 7 = P10 BSP, class 8 = P10 NGC: both count as P10
      final stats = computeStats([
        scan('a', [7, 8]),
      ]);
      expect(stats.byDenomination.length, 1);
      expect(stats.byDenomination.first.count, 2);
    });

    test('empty list is safe', () {
      final stats = computeStats([]);
      expect(stats.isEmpty, isTrue);
      expect(stats.averageCentavos, 0);
      expect(stats.byDenomination, isEmpty);
    });

    test('the average is rounded to a centavo', () {
      // 10.00 + 10.00 + 0.05 = 20.05 over 3 sessions = 6.6833 -> 6.68
      final stats = computeStats([
        scan('a', [7]),
        scan('b', [7]),
        scan('c', [1]),
      ]);
      expect(stats.averageCentavos, 668);
    });
  });

  Future<void> pumpScreen(WidgetTester tester, List<ScanRecord> seed) async {
    tester.view.physicalSize = const Size(1080, 2600);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    final history = HistoryProvider(
      InMemoryScanRepository(seed: seed),
      AuthProvider(),
    );
    await history.load();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: history,
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const StatisticsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle(); // let the bars finish growing
  }

  testWidgets('shows the totals and the frequency bars', (tester) async {
    await pumpScreen(tester, [
      scan('a', [7, 7]),
      scan('b', [7, 12]),
    ]);

    expect(find.text('Statistics'), findsOneWidget);
    expect(find.text('TOTAL SCANNED'), findsOneWidget);
    expect(find.text('₱130.00'), findsOneWidget);
    expect(find.text('ITEMS DETECTED'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('SCAN SESSIONS'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('₱65.00'), findsOneWidget); // average
    expect(find.text('Denomination Frequency'), findsOneWidget);
    expect(find.text('3 items'), findsOneWidget);
    expect(find.text('1 item'), findsOneWidget);
  });

  testWidgets('shows an empty state without scans', (tester) async {
    await pumpScreen(tester, []);
    expect(find.text('No statistics yet'), findsOneWidget);
    expect(find.text('TOTAL SCANNED'), findsNothing);
  });
}
