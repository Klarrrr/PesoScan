import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_result.dart';
import '../services/supabase_service.dart';

/// Where the user is in the login flow.
enum AuthStatus { unknown, signedOut, awaitingCode, signedIn }

class AuthProvider extends ChangeNotifier {
  AuthStatus _status = AuthStatus.signedOut;
  String? _userId;
  String? _username;
  String? _email;
  StreamSubscription<dynamic>? _subscription;

  AuthProvider() {
    if (SupabaseService.isReady) {
      _syncFromSession();
      // Supabase tells us whenever someone signs in or out.
      _subscription = SupabaseService.client.auth.onAuthStateChange.listen(
        (_) => _syncFromSession(),
      );
    }
  }

  AuthStatus get status => _status;
  String? get userId => _userId;
  String? get username => _username;
  String? get email => _email;
  bool get isSignedIn => _status == AuthStatus.signedIn;

  SupabaseClient get _client => SupabaseService.client;

  AuthResult? _notReady() => SupabaseService.isReady
      ? null
      : const AuthResult.failure(
          'The app is not connected to the server. Check env.json.',
        );

  void _syncFromSession() {
    final user = _client.auth.currentSession?.user;
    if (user == null) {
      _status = AuthStatus.signedOut;
      _userId = null;
      _username = null;
      _email = null;
    } else {
      _status = AuthStatus.signedIn;
      _userId = user.id;
      _email = user.email;
      _username = user.userMetadata?['username'] as String?;
    }
    notifyListeners();
  }

  /// Create an account. Supabase emails a 6-digit code.
  Future<AuthResult> register({
    required String username,
    required String email,
    required String password,
  }) async {
    final notReady = _notReady();
    if (notReady != null) return notReady;
    try {
      // Is the username free? (database function from Part 4)
      final free = await _client.rpc(
        'username_available',
        params: {'name': username},
      );
      if (free != true) {
        return const AuthResult.failure('That username is already taken.');
      }

      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'username': username}, // the database trigger copies this
      );

      // With "Confirm email" ON, an already-registered email comes back
      // as a user with NO identities (Supabase hides that it exists).
      final identities = response.user?.identities;
      if (identities != null && identities.isEmpty) {
        return const AuthResult.failure(
          'An account with this email already exists. Please log in.',
        );
      }
      return const AuthResult.success();
    } catch (e) {
      return AuthResult.failure(friendlyAuthError(e));
    }
  }

  Future<AuthResult> verifySignupCode({
    required String email,
    required String code,
  }) async {
    final notReady = _notReady();
    if (notReady != null) return notReady;
    try {
      final res = await _client.auth.verifyOTP(
        email: email,
        token: code,
        type: OtpType.signup,
      );
      if (res.session == null) {
        return const AuthResult.failure('Could not verify. Please try again.');
      }
      _syncFromSession();
      return const AuthResult.success();
    } catch (e) {
      return AuthResult.failure(friendlyAuthError(e));
    }
  }

  Future<AuthResult> resendSignupCode(String email) async {
    final notReady = _notReady();
    if (notReady != null) return notReady;
    try {
      await _client.auth.resend(type: OtpType.signup, email: email);
      return const AuthResult.success();
    } catch (e) {
      return AuthResult.failure(friendlyAuthError(e));
    }
  }

  /// PART 5 ONLY: checks the password. Part 6 adds the emailed code.
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final notReady = _notReady();
    if (notReady != null) return notReady;
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
      return const AuthResult.success();
    } on AuthException catch (e) {
      if (e.code == 'email_not_confirmed') {
        return const AuthResult.failure(
          'Please verify your email first.',
          needsEmailVerification: true,
        );
      }
      return AuthResult.failure(friendlyAuthError(e));
    } catch (e) {
      return AuthResult.failure(friendlyAuthError(e));
    }
  }

  Future<void> logout() async {
    if (!SupabaseService.isReady) return;
    try {
      await _client.auth.signOut();
    } catch (_) {
      // Offline: nothing more to do in Part 5. Part 7 handles this properly.
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @visibleForTesting
  void debugSetStatus(AuthStatus status) {
    _status = status;
    notifyListeners();
  }
}
