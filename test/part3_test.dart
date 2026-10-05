import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pesoscan/core/app_theme.dart';
import 'package:pesoscan/providers/settings_provider.dart';
import 'package:pesoscan/screens/onboarding/onboarding_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('onboarding follows the prototype pages', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsProvider();
    await settings.load();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: settings,
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const OnboardingScreen(),
        ),
      ),
    );

    // Page 1
    expect(find.text('Place Currency on a Flat Surface'), findsOneWidget);
    expect(
      find.text('Plain white or dark backgrounds work best.'),
      findsOneWidget,
    );
    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);

    // Page 2
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Overlapping'), findsOneWidget);

    // Page 3: button changes, Skip stays (as in the prototype)
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Instant Value Calculation'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
  });
}
