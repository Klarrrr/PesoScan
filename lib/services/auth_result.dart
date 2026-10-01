import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

// ignore: unused_import
import 'package:flutter/foundation.dart';

/// What every auth action returns: it worked, or here is a message to show.
class AuthResult {
  final bool ok;
  final String message;

  /// Login found an account whose email was never verified.
  final bool needsEmailVerification;

  const AuthResult._(this.ok, this.message, this.needsEmailVerification);

  const AuthResult.success() : this._(true, '', false);

  const AuthResult.failure(
    String message, {
    bool needsEmailVerification = false,
  }) : this._(false, message, needsEmailVerification);
}

/// Turns technical errors into messages a normal person can understand.
/// Turns technical errors into messages a normal person can understand.
String friendlyAuthError(Object error) {
  // Temporary while testing: shows the REAL reason in the Debug Console.
  debugPrint('AUTH ERROR -> ${error.runtimeType}: $error');

  // The server answered with an error (5xx): NOT a connection problem.
  if (error is AuthRetryableFetchException) {
    final status = int.tryParse(error.statusCode ?? '');
    final message = error.message.toLowerCase();

    if (message.contains('sending') && message.contains('email')) {
      return 'We could not send the email right now. Please try again in a moment.';
    }
    if (status != null && status >= 500) {
      return 'The server had a problem. Please try again in a moment.';
    }
    return 'No internet connection. Please check it and try again.';
  }

  if (error is SocketException) {
    return 'No internet connection. Please check it and try again.';
  }

  if (error is AuthException) {
    switch (error.code) {
      case 'invalid_credentials':
        return 'Incorrect email or password.';
      case 'email_not_confirmed':
        return 'Please verify your email first.';
      case 'over_email_send_rate_limit':
      case 'over_request_rate_limit':
        return 'Too many requests. Please wait a minute and try again.';
      case 'otp_expired':
        return 'That code is incorrect or has expired.';
      case 'weak_password':
        return 'That password is too weak. Try a longer one.';
      case 'user_already_exists':
      case 'email_exists':
        return 'An account with this email already exists.';
      case 'same_password':
        return 'Choose a password you have not used before.';
    }
    // Our database rejects a duplicate username while creating the profile.
    if (error.message.contains('Database error')) {
      return 'That username is already taken.';
    }
    return error.message;
  }

  final text = error.toString();
  if (text.contains('SocketException') || text.contains('ClientException')) {
    return 'No internet connection. Please check it and try again.';
  }
  return 'Something went wrong. Please try again.';
}
