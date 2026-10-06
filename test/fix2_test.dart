import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:pesoscan/core/app_theme.dart';
import 'package:pesoscan/providers/auth_provider.dart';
import 'package:pesoscan/providers/history_provider.dart';
import 'package:pesoscan/screens/settings/account_details_screen.dart';
import 'package:pesoscan/screens/settings/change_password_screen.dart';
import 'package:pesoscan/services/auth_result.dart';
import 'package:pesoscan/services/scan_repository.dart';
import 'package:provider/provider.dart';

/// Records what the screens ask the auth provider to do.
class _SpyAuth extends AuthProvider {
  int logoutCalls = 0;
  int changeCalls = 0;
  String? lastCurrent;
  String? lastNew;
  AuthResult changeResult = const AuthResult.success();

  @override
  Future<void> logout() async {
    logoutCalls++;
  }

  @override
  Future<AuthResult> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    changeCalls++;
    lastCurrent = currentPassword;
    lastNew = newPassword;
    return changeResult;
  }
}

class _FakeAuth extends AuthProvider {
  int verifyCalls = 0;

  @override
  String? get username => 'juan';

  @override
  String? get email => 'juan.dela@gmail.com';

  @override
  DateTime? get memberSince => DateTime(2026, 9, 1);

  @override
  DateTime? get lastSignIn => DateTime(2026, 10, 3);

  @override
  Future<AuthResult> verifyPassword(String password) async {
    verifyCalls++;
    return password == 'secret123'
        ? const AuthResult.success()
        : const AuthResult.failure('Incorrect password.');
  }
}

Widget _app(AuthProvider auth, Widget home) {
  final history = HistoryProvider(InMemoryScanRepository(), auth);
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(value: auth),
      ChangeNotifierProvider<HistoryProvider>.value(value: history),
    ],
    child: MaterialApp(theme: AppTheme.dark, home: home),
  );
}

class _Home extends StatelessWidget {
  const _Home();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: ElevatedButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => const ChangePasswordScreen()),
        ),
        child: const Text('open'),
      ),
    ),
  );
}

void _bigScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2600);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
}

Future<void> _enter(WidgetTester tester, String key, String text) =>
    tester.enterText(find.byKey(Key(key)), text);

void main() {
  const dot = '\u2022';

  test('maskEmail hides most of the address', () {
    expect(maskEmail('juan.dela@gmail.com'), 'ju${dot * 6}@gmail.com');
    expect(maskEmail('a@b.com'), 'a${dot * 3}@b.com');
    expect(maskEmail('nonsense'), dot * 8);
  });

  group('AuthProvider without a server', () {
    test('password checks fail clearly instead of crashing', () async {
      final auth = AuthProvider();
      final check = await auth.verifyPassword('x');
      expect(check.ok, isFalse);
      expect(check.message, contains('not connected'));

      final change = await auth.changePassword(
        currentPassword: 'a',
        newPassword: 'b',
      );
      expect(change.ok, isFalse);
    });
  });

  group('ChangePasswordScreen', () {
    Future<_SpyAuth> openScreen(WidgetTester tester) async {
      _bigScreen(tester);
      final auth = _SpyAuth();
      await tester.pumpWidget(_app(auth, const _Home()));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Change Password'), findsOneWidget);
      return auth;
    }

    testWidgets('Cancel returns to the previous screen and never signs out', (
      tester,
    ) async {
      final auth = await openScreen(tester);

      await tester.ensureVisible(find.byKey(const Key('btn-cancel')));
      await tester.tap(find.byKey(const Key('btn-cancel')));
      await tester.pumpAndSettle();

      expect(find.text('Change Password'), findsNothing);
      expect(find.text('open'), findsOneWidget);
      expect(auth.logoutCalls, 0);
      expect(auth.changeCalls, 0);
    });

    testWidgets('the Back button returns and never signs out', (tester) async {
      final auth = await openScreen(tester);

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('Change Password'), findsNothing);
      expect(find.text('open'), findsOneWidget);
      expect(auth.logoutCalls, 0);
    });

    testWidgets('a correct change saves, goes back and stays signed in', (
      tester,
    ) async {
      final auth = await openScreen(tester);

      await _enter(tester, 'field-current', 'oldpass12');
      await _enter(tester, 'field-new', 'newpass12');
      await _enter(tester, 'field-confirm', 'newpass12');
      await tester.ensureVisible(find.text('Save Password'));
      await tester.tap(find.text('Save Password'));
      await tester.pumpAndSettle();

      expect(auth.changeCalls, 1);
      expect(auth.lastCurrent, 'oldpass12');
      expect(auth.lastNew, 'newpass12');
      expect(auth.logoutCalls, 0);
      expect(find.text('Change Password'), findsNothing);
      expect(find.text('Password updated'), findsOneWidget);
    });

    testWidgets('a mismatch or an unchanged password is refused', (
      tester,
    ) async {
      final auth = await openScreen(tester);

      await _enter(tester, 'field-current', 'oldpass12');
      await _enter(tester, 'field-new', 'newpass12');
      await _enter(tester, 'field-confirm', 'different12');
      await tester.ensureVisible(find.text('Save Password'));
      await tester.tap(find.text('Save Password'));
      await tester.pumpAndSettle();
      expect(find.text('Passwords do not match'), findsOneWidget);

      await _enter(tester, 'field-current', 'samepass12');
      await _enter(tester, 'field-new', 'samepass12');
      await _enter(tester, 'field-confirm', 'samepass12');
      await tester.tap(find.text('Save Password'));
      await tester.pumpAndSettle();
      expect(find.text('Choose a different password'), findsOneWidget);

      expect(auth.changeCalls, 0);
    });

    testWidgets('a wrong current password shows a message and stays here', (
      tester,
    ) async {
      final auth = await openScreen(tester);
      auth.changeResult = const AuthResult.failure('Incorrect password.');

      await _enter(tester, 'field-current', 'wrongpass1');
      await _enter(tester, 'field-new', 'newpass12');
      await _enter(tester, 'field-confirm', 'newpass12');
      await tester.ensureVisible(find.text('Save Password'));
      await tester.tap(find.text('Save Password'));
      await tester.pumpAndSettle();

      expect(find.text('Incorrect password.'), findsOneWidget);
      expect(find.text('Change Password'), findsOneWidget);
      expect(auth.logoutCalls, 0);
    });
  });

  group('AccountDetailsScreen', () {
    Future<_FakeAuth> openDetails(WidgetTester tester) async {
      _bigScreen(tester);
      final auth = _FakeAuth();
      await tester.pumpWidget(_app(auth, const AccountDetailsScreen()));
      return auth;
    }

    Future<void> unlock(WidgetTester tester, String password) async {
      await tester.tap(find.byKey(const Key('btn-unlock')));
      await tester.pumpAndSettle();
      await _enter(tester, 'verify-password-field', password);
      await tester.tap(find.text('Unlock'));
      await tester.pumpAndSettle();
    }

    testWidgets('everything private starts hidden', (tester) async {
      await openDetails(tester);

      expect(find.text('juan'), findsOneWidget);
      expect(find.text(maskEmail('juan.dela@gmail.com')), findsOneWidget);
      expect(find.text('juan.dela@gmail.com'), findsNothing);
      // password, member since, last sign-in, scans
      expect(find.text(dot * 8), findsNWidgets(4));
      expect(find.byKey(const Key('btn-unlock')), findsOneWidget);
    });

    testWidgets('a wrong password keeps it locked', (tester) async {
      final auth = await openDetails(tester);
      await unlock(tester, 'wrong');

      expect(auth.verifyCalls, 1);
      expect(find.text('Incorrect password.'), findsOneWidget);
      expect(find.text('juan.dela@gmail.com'), findsNothing);
    });

    testWidgets('Cancel keeps it locked without checking anything', (
      tester,
    ) async {
      final auth = await openDetails(tester);

      await tester.tap(find.byKey(const Key('btn-unlock')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(auth.verifyCalls, 0);
      expect(find.text('juan.dela@gmail.com'), findsNothing);
    });

    testWidgets('the right password reveals details, but never the password', (
      tester,
    ) async {
      await openDetails(tester);
      await unlock(tester, 'secret123');

      expect(find.text('juan.dela@gmail.com'), findsOneWidget);
      expect(
        find.text(DateFormat('MMM d, yyyy').format(DateTime(2026, 9, 1))),
        findsOneWidget,
      );
      expect(find.text(dot * 8), findsOneWidget); // only the password row
      expect(find.text('secret123'), findsNothing);
      expect(find.byKey(const Key('btn-hide')), findsOneWidget);
    });

    testWidgets('Hide details and the 1 minute timer lock it again', (
      tester,
    ) async {
      await openDetails(tester);

      await unlock(tester, 'secret123');
      await tester.tap(find.byKey(const Key('btn-hide')));
      await tester.pump();
      expect(find.text('juan.dela@gmail.com'), findsNothing);

      await unlock(tester, 'secret123');
      expect(find.text('juan.dela@gmail.com'), findsOneWidget);
      await tester.pump(const Duration(seconds: 61));
      await tester.pump();
      expect(find.text('juan.dela@gmail.com'), findsNothing);
    });
  });
}
