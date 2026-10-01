import 'package:flutter_test/flutter_test.dart';
import 'package:pesoscan/providers/auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('a remembered login survives a restart (works offline)', () async {
    SharedPreferences.setMockInitialValues({
      'auth_user_id': 'user-1',
      'auth_email': 'juan@example.com',
      'auth_username': 'juan',
    });

    final auth = AuthProvider();
    await auth.load(); // Supabase is not started in tests = "offline"

    expect(auth.isSignedIn, isTrue);
    expect(auth.username, 'juan');
    expect(auth.email, 'juan@example.com');
  });

  test('logout forgets the user even without internet', () async {
    SharedPreferences.setMockInitialValues({
      'auth_user_id': 'user-1',
      'auth_email': 'juan@example.com',
      'auth_username': 'juan',
    });

    final auth = AuthProvider();
    await auth.load();
    await auth.logout();

    expect(auth.isSignedIn, isFalse);
    expect(auth.username, isNull);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('auth_user_id'), isNull);
  });

  test('nothing remembered means signed out', () async {
    SharedPreferences.setMockInitialValues({});
    final auth = AuthProvider();
    await auth.load();
    expect(auth.status, AuthStatus.signedOut);
  });
}
