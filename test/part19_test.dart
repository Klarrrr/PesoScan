import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pesoscan/core/app_theme.dart';
import 'package:pesoscan/data/help_content.dart';
import 'package:pesoscan/data/legal_content.dart';
import 'package:pesoscan/screens/info/help_faq_screen.dart';
import 'package:pesoscan/screens/info/legal_screen.dart';

void main() {
  group('content', () {
    test('every FAQ and legal section has a title and text', () {
      for (final s in [...faqItems(), ...termsSections, ...privacySections]) {
        expect(s.title.trim(), isNotEmpty);
        expect(s.body.trim().length, greaterThan(20));
      }
    });

    test('titles are not repeated inside one page', () {
      for (final list in [faqItems(), termsSections, privacySections]) {
        final titles = list.map((s) => s.title).toList();
        expect(titles.toSet().length, titles.length);
      }
    });

    test('the documents describe what the app really does', () {
      final terms = termsSections.map((s) => s.body).join(' ');
      final privacy = privacySections.map((s) => s.body).join(' ');
      expect(terms, contains('counterfeit'));
      expect(privacy, contains('Supabase'));
      expect(
        privacy,
        contains('R.A. 10173'.replaceAll('R.A. ', 'Republic Act No. ')),
      );
      expect(privacy, contains('never uploaded'));
    });

    test('the FAQ numbers follow the class list', () {
      final supported = faqItems().firstWhere(
        (s) => s.title.startsWith('Which coins'),
      );
      expect(supported.body, contains('9 kinds of coins'));
      expect(supported.body, contains('10 kinds of bills'));
    });
  });

  testWidgets('FAQ answers open and close when tapped', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.dark, home: const HelpFaqScreen()),
    );

    final first = faqItems().first;
    expect(find.text('Quick Scanning Tips'), findsOneWidget);
    expect(find.text(first.title), findsOneWidget);
    expect(find.text(first.body), findsNothing); // closed

    await tester.tap(find.byKey(const Key('faq-0')));
    await tester.pumpAndSettle();
    expect(find.text(first.body), findsOneWidget); // open

    await tester.tap(find.byKey(const Key('faq-0')));
    await tester.pumpAndSettle();
    expect(find.text(first.body), findsNothing); // closed again
  });

  testWidgets('legal page shows its title, date and an open first section', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const LegalScreen(
          title: 'Terms of Service',
          subtitle: 'Please read before using PesoScan',
          sections: termsSections,
        ),
      ),
    );

    expect(find.text('Terms of Service'), findsOneWidget);
    expect(find.text('Last updated: $legalLastUpdated'), findsOneWidget);
    expect(find.text(termsSections.first.body), findsOneWidget);
    expect(find.text(termsSections[1].body), findsNothing);
  });
}
