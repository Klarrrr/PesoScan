import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pesoscan/core/app_theme.dart';
import 'package:pesoscan/core/validators.dart';
import 'package:pesoscan/providers/auth_provider.dart';
import 'package:pesoscan/screens/auth/login_screen.dart';
import 'package:provider/provider.dart';

void main() {
  group('Validators', () {
    test('username', () {
      expect(Validators.username(''), isNotNull);
      expect(Validators.username('ab'), isNotNull);
      expect(Validators.username('has space'), isNotNull);
      expect(Validators.username('juan_123'), isNull);
    });

    test('email', () {
      expect(Validators.email('nope'), isNotNull);
      expect(Validators.email('a@b'), isNotNull);
      expect(Validators.email('juan@example.com'), isNull);
    });

    test('new password needs 8+ characters, letters and numbers', () {
      expect(Validators.newPassword('short1'), isNotNull);
      expect(Validators.newPassword('onlyletters'), isNotNull);
      expect(Validators.newPassword('12345678'), isNotNull);
      expect(Validators.newPassword('coins2026'), isNull);
    });

    test('confirm password', () {
      expect(Validators.confirmPassword('abc', 'xyz'), isNotNull);
      expect(Validators.confirmPassword('abc12345', 'abc12345'), isNull);
    });

    test('code', () {
      expect(Validators.code('123'), isNotNull);
      expect(Validators.code('12345a'), isNotNull);
      expect(Validators.code('123456'), isNull);
    });
  });

  testWidgets('login shows errors when the form is empty', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthProvider(),
        child: MaterialApp(theme: AppTheme.dark, home: const LoginScreen()),
      ),
    );

    await tester.ensureVisible(find.text('Log In'));
    await tester.tap(find.text('Log In'));
    await tester.pump();

    expect(find.text('Enter your email'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
  });
}
