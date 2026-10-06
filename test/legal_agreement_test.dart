import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pesoscan/core/app_theme.dart';
import 'package:pesoscan/data/legal_content.dart';
import 'package:pesoscan/providers/auth_provider.dart';
import 'package:pesoscan/screens/auth/login_screen.dart';
import 'package:pesoscan/screens/auth/register_screen.dart';
import 'package:pesoscan/services/auth_result.dart';
import 'package:pesoscan/services/terms_consent.dart';
import 'package:pesoscan/widgets/agreement_field.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Counts the attempts and always answers "failed", so no screen opens.
class _SpyAuth extends AuthProvider {
  int registerCalls = 0;
  int loginCalls = 0;

  @override
  Future<AuthResult> register({
    required String username,
    required String email,
    required String password,
  }) async {
    registerCalls++;
    return const AuthResult.failure('Stopped for the test.');
  }

  @override
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    loginCalls++;
    return const AuthResult.failure('Stopped for the test.');
  }
}

void _bigScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2600);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
}

Widget _authApp(AuthProvider auth, Widget home) =>
    ChangeNotifierProvider<AuthProvider>.value(
      value: auth,
      child: MaterialApp(theme: AppTheme.dark, home: home),
    );

/// A screen with one button that opens the panel and reports the answer.
Widget _panelHost(void Function(bool) onResult, {bool agreed = false}) {
  return MaterialApp(
    theme: AppTheme.dark,
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () async =>
                onResult(await LegalPanel.show(context, agreed: agreed)),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
}

Future<void> _openPanel(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  group('TermsConsent', () {
    test('remembers the agreement', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await TermsConsent.isAccepted(), isFalse);
      await TermsConsent.accept();
      expect(await TermsConsent.isAccepted(), isTrue);
    });

    test('an older version must be accepted again', () async {
      SharedPreferences.setMockInitialValues({
        TermsConsent.storageKey: TermsConsent.currentVersion - 1,
      });
      expect(await TermsConsent.isAccepted(), isFalse);
    });
  });

  group('LegalPanel', () {
    testWidgets('opens on Terms of Service with its text already showing', (
      tester,
    ) async {
      _bigScreen(tester);
      await tester.pumpWidget(_panelHost((_) {}));
      await _openPanel(tester);

      expect(find.byKey(const Key('tab-terms')), findsOneWidget);
      expect(find.byKey(const Key('tab-privacy')), findsOneWidget);
      expect(find.text(termsSections.first.body), findsOneWidget);
      expect(find.text(privacySections.first.body), findsNothing);
    });

    testWidgets('the tabs switch between the two documents', (tester) async {
      _bigScreen(tester);
      await tester.pumpWidget(_panelHost((_) {}));
      await _openPanel(tester);

      await tester.tap(find.byKey(const Key('tab-privacy')));
      await tester.pumpAndSettle();
      expect(find.text(privacySections.first.body), findsOneWidget);
      expect(find.text(termsSections.first.body), findsNothing);

      await tester.tap(find.byKey(const Key('tab-terms')));
      await tester.pumpAndSettle();
      expect(find.text(termsSections.first.body), findsOneWidget);
    });

    testWidgets('ticking the box and pressing Done answers yes', (
      tester,
    ) async {
      _bigScreen(tester);
      bool? result;
      await tester.pumpWidget(_panelHost((v) => result = v));
      await _openPanel(tester);

      await tester.tap(find.byKey(const Key('panel-checkbox')));
      await tester.pump();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
    });

    testWidgets('an earlier yes can be taken back', (tester) async {
      _bigScreen(tester);
      bool? result;
      await tester.pumpWidget(_panelHost((v) => result = v, agreed: true));
      await _openPanel(tester);

      await tester.tap(find.byKey(const Key('panel-checkbox')));
      await tester.pump();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(result, isFalse);
    });
  });

  group('AgreementField', () {
    testWidgets('the box fills with a check, and the button opens the panel', (
      tester,
    ) async {
      _bigScreen(tester);
      var agreed = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => Padding(
                padding: const EdgeInsets.all(16),
                child: AgreementField(
                  agreed: agreed,
                  showError: false,
                  onChanged: (v) => setState(() => agreed = v),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.check_rounded), findsNothing);
      await tester.tap(find.byKey(const Key('agree-box')));
      await tester.pump();
      expect(agreed, isTrue);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);

      // Untick, then tick it again from inside the panel.
      await tester.tap(find.byKey(const Key('agree-box')));
      await tester.pump();
      expect(agreed, isFalse);

      await tester.tap(find.byKey(const Key('btn-legal')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('tab-terms')), findsOneWidget);
      await tester.tap(find.byKey(const Key('panel-checkbox')));
      await tester.pump();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(agreed, isTrue);
    });

    testWidgets('shows a message when the box is empty and an error is due', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: AgreementField(
              agreed: false,
              showError: true,
              onChanged: (_) {},
            ),
          ),
        ),
      );
      expect(find.textContaining('Please agree'), findsOneWidget);
    });
  });

  group('Create Account', () {
    testWidgets('needs the box ticked', (tester) async {
      _bigScreen(tester);
      SharedPreferences.setMockInitialValues({});
      final auth = _SpyAuth();
      await tester.pumpWidget(_authApp(auth, const RegisterScreen()));

      await tester.enterText(
        find.byKey(const Key('field-username')),
        'juan_123',
      );
      await tester.enterText(
        find.byKey(const Key('field-email')),
        'juan@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('field-password')),
        'coins2026',
      );
      await tester.enterText(
        find.byKey(const Key('field-confirm-password')),
        'coins2026',
      );

      final button = find.byKey(const Key('btn-create-account'));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pump();
      expect(auth.registerCalls, 0);
      expect(find.textContaining('Please agree'), findsOneWidget);

      await tester.tap(find.byKey(const Key('agree-box')));
      await tester.pump();
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(auth.registerCalls, 1);
      expect(find.text('Stopped for the test.'), findsOneWidget);
    });
  });

  group('Log In', () {
    Future<void> fillIn(WidgetTester tester) async {
      await tester.enterText(
        find.byKey(const Key('field-login-email')),
        'juan@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('field-login-password')),
        'coins2026',
      );
    }

    testWidgets('needs the box ticked the first time', (tester) async {
      _bigScreen(tester);
      SharedPreferences.setMockInitialValues({});
      final auth = _SpyAuth();
      await tester.pumpWidget(_authApp(auth, const LoginScreen()));
      await tester.pumpAndSettle();

      await fillIn(tester);
      final button = find.byKey(const Key('btn-login'));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pump();
      expect(auth.loginCalls, 0);
      expect(find.textContaining('Please agree'), findsOneWidget);

      await tester.tap(find.byKey(const Key('agree-box')));
      await tester.pump();
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(auth.loginCalls, 1);
    });

    testWidgets('remembers an earlier agreement on this phone', (tester) async {
      _bigScreen(tester);
      SharedPreferences.setMockInitialValues({
        TermsConsent.storageKey: TermsConsent.currentVersion,
      });
      final auth = _SpyAuth();
      await tester.pumpWidget(_authApp(auth, const LoginScreen()));
      await tester.pumpAndSettle(); // lets the saved answer load

      expect(
        find.byIcon(Icons.check_rounded),
        findsOneWidget,
      ); // already ticked

      await fillIn(tester);
      final button = find.byKey(const Key('btn-login'));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(auth.loginCalls, 1);
    });
  });
}
