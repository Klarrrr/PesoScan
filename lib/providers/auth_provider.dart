import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/attempt_limiter.dart';
import '../services/auth_result.dart';
import '../services/supabase_service.dart';

/// Where the user is in the login flow.
enum AuthStatus { unknown, signedOut, awaitingCode, signedIn }

class AuthProvider extends ChangeNotifier {
  // What we remember on the phone, so the app works offline after login.
  static const _kId = 'auth_user_id';
  static const _kEmail = 'auth_email';
  static const _kUsername = 'auth_username';

  SharedPreferences? _prefs;
  AuthStatus _status = AuthStatus.unknown;
  String? _userId;
  String? _username;
  String? _email;
  StreamSubscription<dynamic>? _subscription;
  final AttemptLimiter _limiter = AttemptLimiter();

  /// True during a multi-step flow (login code, password reset).
  /// While true, Supabase session events are ignored.
  bool _signInInProgress = false;

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

  // ---------------------------------------------------------------
  // Startup: restore a remembered login (works offline)
  // ---------------------------------------------------------------

  /// Call once in main(), before runApp().
  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();

    final id = _prefs!.getString(_kId);
    if (id != null) {
      _status = AuthStatus.signedIn;
      _userId = id;
      _email = _prefs!.getString(_kEmail);
      _username = _prefs!.getString(_kUsername);
    } else {
      _status = AuthStatus.signedOut;
    }

    if (SupabaseService.isReady) {
      final user = _client.auth.currentSession?.user;
      if (user != null) await _remember(user);
      _subscription = _client.auth.onAuthStateChange.listen(_onAuthEvent);
    }
    notifyListeners();
  }

  void _onAuthEvent(dynamic data) {
    if (_signInInProgress) return;
    final event = data.event as AuthChangeEvent;
    final user = (data.session as Session?)?.user;

    if (event == AuthChangeEvent.signedOut) {
      // Explicit logout, or the server revoked the session.
      _forget();
    } else if (user != null &&
        (event == AuthChangeEvent.signedIn ||
            event == AuthChangeEvent.tokenRefreshed ||
            event == AuthChangeEvent.userUpdated)) {
      _remember(user);
    }
    // Note: a null session at startup (offline, expired token) is NOT a logout.
  }

  Future<void> _remember(User user) async {
    _status = AuthStatus.signedIn;
    _userId = user.id;
    _email = user.email;
    _username = user.userMetadata?['username'] as String?;
    notifyListeners();

    await _prefs?.setString(_kId, user.id);
    await _prefs?.setString(_kEmail, user.email ?? '');
    await _prefs?.setString(_kUsername, _username ?? '');
  }

  Future<void> _forget() async {
    _status = AuthStatus.signedOut;
    _userId = null;
    _username = null;
    _email = null;
    notifyListeners();

    await _prefs?.remove(_kId);
    await _prefs?.remove(_kEmail);
    await _prefs?.remove(_kUsername);
  }

  String _lockMessage(Duration remaining) =>
      'Too many attempts. Try again in ${AttemptLimiter.format(remaining)}.';

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
  // Register and verify the email
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
      final user = res.session?.user;
      if (user == null) {
        return const AuthResult.failure('Could not verify. Please try again.');
      }
      await _limiter.reset(key);
      _signInInProgress = false;
      await _remember(user);
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
  // Two-step login
  // ---------------------------------------------------------------

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
      await _client.auth.signInWithPassword(email: email, password: password);
      await _client.auth.signOut(scope: SignOutScope.local);
      await _client.auth.signInWithOtp(email: email, shouldCreateUser: false);
      await _limiter.reset(key);
      return const AuthResult.success();
    } on AuthException catch (e) {
      _signInInProgress = false;
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
      return AuthResult.failure(friendlyAuthError(e));
    }
  }

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
      final user = res.session?.user;
      if (user == null) {
        return const AuthResult.failure('Could not sign you in. Try again.');
      }
      await _limiter.reset(key);
      await _limiter.reset('login:$email');
      _signInInProgress = false;
      await _remember(user);
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

  // ---------------------------------------------------------------
  // Forgot password (NEW in Part 7)
  // ---------------------------------------------------------------

  /// Emails a reset code. (Supabase gives the same answer whether or not
  /// the email has an account, so nobody can probe for registered emails.)
  Future<AuthResult> forgotPassword(String email) async {
    final notReady = _notReady();
    if (notReady != null) return notReady;
    try {
      await _client.auth.resetPasswordForEmail(email);
      return const AuthResult.success();
    } catch (e) {
      return AuthResult.failure(friendlyAuthError(e));
    }
  }

  /// Checks the reset code. The user is NOT logged in yet: that only
  /// happens after they choose a new password.
  Future<AuthResult> verifyRecoveryCode({
    required String email,
    required String code,
  }) async {
    final notReady = _notReady();
    if (notReady != null) return notReady;

    final key = 'recovery-code:$email';
    final locked = await _limiter.lockRemaining(key);
    if (locked != null) return AuthResult.failure(_lockMessage(locked));

    _signInInProgress = true;
    try {
      final res = await _client.auth.verifyOTP(
        email: email,
        token: code,
        type: OtpType.recovery,
      );
      if (res.session == null) {
        _signInInProgress = false;
        return const AuthResult.failure('Could not verify. Please try again.');
      }
      await _limiter.reset(key);
      return const AuthResult.success();
    } on AuthException catch (e) {
      _signInInProgress = false;
      if (e.code == 'otp_expired') {
        return _countFailure(key, 'That code is incorrect or has expired.');
      }
      return AuthResult.failure(friendlyAuthError(e));
    } catch (e) {
      _signInInProgress = false;
      return AuthResult.failure(friendlyAuthError(e));
    }
  }

  /// Saves a new password and logs the user in.
  /// Also used later by Settings > change password.
  Future<AuthResult> updatePassword(String newPassword) async {
    final notReady = _notReady();
    if (notReady != null) return notReady;
    try {
      await _client.auth.updateUser(UserAttributes(password: newPassword));
      _signInInProgress = false;
      final user = _client.auth.currentUser;
      if (user != null) await _remember(user);
      return const AuthResult.success();
    } catch (e) {
      return AuthResult.failure(friendlyAuthError(e));
    }
  }

  // ---------------------------------------------------------------
  // Logout
  // ---------------------------------------------------------------

  /// Always signs out on THIS phone, even when offline.
  Future<void> logout() async {
    _signInInProgress = false;
    if (SupabaseService.isReady) {
      try {
        await _client.auth.signOut(scope: SignOutScope.local);
      } catch (_) {
        // No internet: still log out locally below.
      }
    }
    await _forget();
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
