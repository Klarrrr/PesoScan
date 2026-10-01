import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/attempt_limiter.dart';
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
  final AttemptLimiter _limiter = AttemptLimiter();

  /// True between "password was correct" and "code was verified".
  /// While true we ignore Supabase's session events, so the brief
  /// password session is never mistaken for a real login.
  bool _signInInProgress = false;

  AuthProvider() {
    if (SupabaseService.isReady) {
      _syncFromSession();
      _subscription = SupabaseService.client.auth.onAuthStateChange.listen((_) {
        if (!_signInInProgress) _syncFromSession();
      });
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

  String _lockMessage(Duration remaining) =>
      'Too many attempts. Try again in ${AttemptLimiter.format(remaining)}.';

  /// Counts a wrong attempt and builds the message the user sees.
  Future<AuthResult> _countFailure(String key, String message) async {
    final left = await _limiter.recordFailure(key);
    if (left == 0) {
      return AuthResult.failure(_lockMessage(_limiter.lockDuration));
    }
    return AuthResult.failure(
      '$message $left ${left == 1 ? 'attempt' : 'attempts'} left.',
    );
  }

  // ---------------------------------------------------------------
  // Register (unchanged from Part 5)
  // ---------------------------------------------------------------

  Future<AuthResult> register({
    required String username,
    required String email,
    required String password,
  }) async {
    final notReady = _notReady();
    if (notReady != null) return notReady;
    try {
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
        data: {'username': username},
      );

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

    final key = 'signup-code:$email';
    final locked = await _limiter.lockRemaining(key);
    if (locked != null) return AuthResult.failure(_lockMessage(locked));

    try {
      final res = await _client.auth.verifyOTP(
        email: email,
        token: code,
        type: OtpType.signup,
      );
      if (res.session == null) {
        return const AuthResult.failure('Could not verify. Please try again.');
      }
      await _limiter.reset(key);
      _signInInProgress = false;
      _syncFromSession();
      return const AuthResult.success();
    } on AuthException catch (e) {
      if (e.code == 'otp_expired') {
        return _countFailure(key, 'That code is incorrect or has expired.');
      }
      return AuthResult.failure(friendlyAuthError(e));
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

  // ---------------------------------------------------------------
  // Two-step login (NEW in Part 6)
  // ---------------------------------------------------------------

  /// Step 1 and 2: check the password, then email a login code.
  /// Success means "the code was sent", NOT "you are logged in".
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final notReady = _notReady();
    if (notReady != null) return notReady;

    final key = 'login:$email';
    final locked = await _limiter.lockRemaining(key);
    if (locked != null) return AuthResult.failure(_lockMessage(locked));

    _signInInProgress = true;
    try {
      // Check the password...
      await _client.auth.signInWithPassword(email: email, password: password);
      // ...then throw that session away. Real login comes after the code.
      await _client.auth.signOut(scope: SignOutScope.local);
      // Email the code (never creates a new account).
      await _client.auth.signInWithOtp(email: email, shouldCreateUser: false);

      await _limiter.reset(key);
      return const AuthResult.success();
    } on AuthException catch (e) {
      _signInInProgress = false;
      _syncFromSession();
      if (e.code == 'invalid_credentials') {
        return _countFailure(key, 'Incorrect email or password.');
      }
      if (e.code == 'email_not_confirmed') {
        return const AuthResult.failure(
          'Please verify your email first.',
          needsEmailVerification: true,
        );
      }
      return AuthResult.failure(friendlyAuthError(e));
    } catch (e) {
      _signInInProgress = false;
      _syncFromSession();
      return AuthResult.failure(friendlyAuthError(e));
    }
  }

  /// Step 3: the user typed the code from the email.
  Future<AuthResult> verifyLoginCode({
    required String email,
    required String code,
  }) async {
    final notReady = _notReady();
    if (notReady != null) return notReady;

    final key = 'login-code:$email';
    final locked = await _limiter.lockRemaining(key);
    if (locked != null) return AuthResult.failure(_lockMessage(locked));

    try {
      final res = await _client.auth.verifyOTP(
        email: email,
        token: code,
        type: OtpType.email,
      );
      if (res.session == null) {
        return const AuthResult.failure('Could not sign you in. Try again.');
      }
      await _limiter.reset(key);
      await _limiter.reset('login:$email');
      _signInInProgress = false;
      _syncFromSession();
      return const AuthResult.success();
    } on AuthException catch (e) {
      if (e.code == 'otp_expired') {
        return _countFailure(key, 'That code is incorrect or has expired.');
      }
      return AuthResult.failure(friendlyAuthError(e));
    } catch (e) {
      return AuthResult.failure(friendlyAuthError(e));
    }
  }

  Future<AuthResult> resendLoginCode(String email) async {
    final notReady = _notReady();
    if (notReady != null) return notReady;
    try {
      await _client.auth.signInWithOtp(email: email, shouldCreateUser: false);
      return const AuthResult.success();
    } catch (e) {
      return AuthResult.failure(friendlyAuthError(e));
    }
  }

  Future<void> logout() async {
    _signInInProgress = false;
    if (!SupabaseService.isReady) return;
    try {
      await _client.auth.signOut();
    } catch (_) {
      // Offline: Part 7 handles this properly.
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
