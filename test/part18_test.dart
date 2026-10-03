import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pesoscan/core/app_theme.dart';
import 'package:pesoscan/data/currency_reference.dart';
import 'package:pesoscan/models/money_class.dart';
import 'package:pesoscan/screens/info/currency_reference_screen.dart';

void main() {
  test('every class has reference text', () {
    for (final money in MoneyClasses.all) {
      final info = referenceInfo[money.id];
      expect(
        info,
        isNotNull,
        reason: 'class ${money.id} has no reference text',
      );
      expect(info!.look, isNotEmpty);
      expect(info.period, isNotEmpty);
    }
  });

  testWidgets('tabs show the right items and the detail sheet opens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.dark, home: const CurrencyReferenceScreen()),
    );

    expect(find.text('Currency Reference'), findsOneWidget);
    expect(find.text('Coins (9)'), findsOneWidget);
    expect(find.text('Bills (10)'), findsOneWidget);
    expect(find.byKey(const Key('ref-1')), findsOneWidget); // first coin
    expect(find.byKey(const Key('ref-10')), findsNothing); // a bill

    await tester.tap(find.byKey(const Key('tab-bills')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ref-10')), findsOneWidget);
    expect(find.byKey(const Key('ref-1')), findsNothing);

    await tester.tap(find.byKey(const Key('ref-10')));
    await tester.pumpAndSettle();
    expect(find.text('App class 10 · model index 9'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
  });
}
