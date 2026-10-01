import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_routes.dart';
import '../../providers/auth_provider.dart';
import 'code_entry_screen.dart';

/// Opens the code screen for "verify the email of a new account".
void openSignupVerification(BuildContext context, String email) {
  final auth = context.read<AuthProvider>();
  Navigator.pushNamed(
    context,
    AppRoutes.codeEntry,
    arguments: CodeEntryArgs(
      title: 'Verify Your Email',
      subtitle:
          'We sent a 6-digit code to $email. '
          'Enter it below to finish creating your account.',
      onVerify: (code) => auth.verifySignupCode(email: email, code: code),
      onResend: () => auth.resendSignupCode(email),
      onSuccess: (ctx) =>
          Navigator.pushNamedAndRemoveUntil(ctx, AppRoutes.home, (_) => false),
    ),
  );
}

/// Opens the code screen for the second step of logging in.
void openLoginCode(BuildContext context, String email) {
  final auth = context.read<AuthProvider>();
  Navigator.pushNamed(
    context,
    AppRoutes.codeEntry,
    arguments: CodeEntryArgs(
      title: 'Two-Step Verification',
      subtitle:
          'We sent a 6-digit login code to $email. '
          'Enter it to finish signing in.',
      onVerify: (code) => auth.verifyLoginCode(email: email, code: code),
      onResend: () => auth.resendLoginCode(email),
      onSuccess: (ctx) =>
          Navigator.pushNamedAndRemoveUntil(ctx, AppRoutes.home, (_) => false),
    ),
  );
}

/// Opens the code screen for "forgot password".
void openRecoveryCode(BuildContext context, String email) {
  final auth = context.read<AuthProvider>();
  Navigator.pushNamed(
    context,
    AppRoutes.codeEntry,
    arguments: CodeEntryArgs(
      title: 'Enter Reset Code',
      subtitle:
          'If an account exists for $email, we sent a 6-digit code. '
          'Enter it to choose a new password.',
      onVerify: (code) => auth.verifyRecoveryCode(email: email, code: code),
      onResend: () => auth.forgotPassword(email),
      onSuccess: (ctx) =>
          Navigator.pushReplacementNamed(ctx, AppRoutes.newPassword),
    ),
  );
}
