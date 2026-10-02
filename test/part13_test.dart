import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pesoscan/core/date_groups.dart';
import 'package:pesoscan/core/scan_search.dart';
import 'package:pesoscan/providers/auth_provider.dart';
import 'package:pesoscan/providers/history_provider.dart';
import 'package:pesoscan/services/sample_data.dart';
import 'package:pesoscan/services/scan_repository.dart';
import 'package:pesoscan/widgets/confirm_tap_button.dart';

final fixedNow = DateTime(2026, 10, 1, 12); // a Thursday

void main() {
  group('date groups', () {
    test('labels', () {
      expect(dateGroupLabel(DateTime(2026, 10, 1, 8), fixedNow), 'Today');
      expect(dateGroupLabel(DateTime(2026, 9, 30), fixedNow), 'Yesterday');
      expect(dateGroupLabel(DateTime(2026, 9, 29), fixedNow), 'This Week');
      expect(dateGroupLabel(DateTime(2026, 9, 27), fixedNow), 'Last Week');
      expect(dateGroupLabel(DateTime(2026, 9, 14), fixedNow), 'September 2026');
      expect(dateGroupLabel(DateTime(2026, 8, 20), fixedNow), 'August 2026');
    });
  });

  group('search', () {
    final scan = devSampleScans(now: fixedNow).first; // ids 7,7,6,5,3,4,1

    test('matches designs, amounts, types and dates', () {
      expect(scanMatchesQuery(scan, 'bsp', now: fixedNow), isTrue);
      expect(scanMatchesQuery(scan, 'bsp coin', now: fixedNow), isTrue);
      expect(scanMatchesQuery(scan, '₱10', now: fixedNow), isTrue);
      expect(scanMatchesQuery(scan, '32.05', now: fixedNow), isTrue);
      expect(scanMatchesQuery(scan, 'today', now: fixedNow), isTrue);
      expect(scanMatchesQuery(scan, '', now: fixedNow), isTrue);
    });

    test('rejects things that are not in the scan', () {
      expect(scanMatchesQuery(scan, 'polymer', now: fixedNow), isFalse);
      expect(scanMatchesQuery(scan, 'bsp bill', now: fixedNow), isFalse);
    });
  });

  group('HistoryProvider', () {
    late HistoryProvider history;

    setUp(() async {
      history = HistoryProvider(
        InMemoryScanRepository(seed: devSampleScans(now: fixedNow)),
        AuthProvider(),
        now: () => fixedNow,
      );
      await history.load();
    });

    test('loads newest first and groups by date', () {
      expect(history.count, 8);
      expect(
        history.all.first.createdAt.isAfter(history.all.last.createdAt),
        isTrue,
      );
      expect(history.groups.map((g) => g.label).toList(), [
        'Today',
        'Yesterday',
        'This Week',
        'Last Week',
        'September 2026',
        'August 2026',
      ]);
      expect(history.recent.length, 3);
    });

    test('search narrows the list and clearFilters restores it', () {
      history.setQuery('polymer');
      expect(history.filtered.length, 2);

      history.setQuery('zzz');
      expect(history.filtered, isEmpty);
      expect(history.hasFilters, isTrue);

      history.clearFilters();
      expect(history.filtered.length, 8);
      expect(history.hasFilters, isFalse);
    });

    test('date range includes both end days', () {
      history.setRange(
        DateTimeRange(start: DateTime(2026, 9, 30), end: DateTime(2026, 10, 1)),
      );
      expect(history.filtered.length, 3); // 2 today + 1 yesterday
    });

    test('delete and clearAll', () async {
      await history.delete(history.all.first);
      expect(history.count, 7);

      await history.clearAll();
      expect(history.count, 0);
    });
  });

  testWidgets('ConfirmTapButton needs two taps and relaxes after a timeout', (
    tester,
  ) async {
    var confirmed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ConfirmTapButton(
              onConfirmed: () => confirmed++,
              builder: (context, armed) => Text(armed ? 'Sure?' : 'Delete'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Delete'));
    await tester.pump();
    expect(find.text('Sure?'), findsOneWidget);
    expect(confirmed, 0);

    await tester.pump(const Duration(seconds: 4)); // the timeout passes
    expect(find.text('Delete'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pump();
    await tester.tap(find.text('Sure?'));
    await tester.pump();
    expect(confirmed, 1);
    expect(find.text('Delete'), findsOneWidget);
  });
}
