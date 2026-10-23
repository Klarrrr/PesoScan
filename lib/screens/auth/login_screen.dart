import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_routes.dart';
import '../../core/validators.dart';
import '../../providers/auth_provider.dart';
import '../../services/terms_consent.dart';
import '../../widgets/agreement_field.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/auth_scaffold.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/gold_button.dart';
import '../../widgets/hcaptcha_dialog.dart';
import 'auth_flows.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _captchaController = HCaptchaBoxController();

  bool _loading = false;
  bool _agreed = false;
  bool _agreementError = false;
  String? _captchaToken;
  String? _error;

  @override
  void initState() {
    super.initState();
    TermsConsent.isAccepted().then((accepted) {
      if (mounted && accepted) {
        setState(() => _agreed = true);
      }
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final formOk = _formKey.currentState!.validate();
    setState(() => _agreementError = !_agreed);
    if (!formOk || !_agreed) {
      return;
    }

    final token = _captchaToken;
    if (token == null) {
      setState(() => _error = 'Please complete the security verification.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final auth = context.read<AuthProvider>();
    final email = _email.text.trim().toLowerCase();
    final result = await auth.login(
      email: email,
      password: _password.text,
      captchaToken: token,
    );
    if (!mounted) {
      return;
    }

    // Reset the "I am human" box after the attempt
    _captchaController.reset();

    if (result.ok) {
      await TermsConsent.accept();
      if (!mounted) {
        return;
      }
      setState(() => _loading = false);
      openLoginCode(context, email); // Opens the 6-digit MFA code screen
      return;
    }

    // Account exists but email was never verified: the signup code was already
    // resent inside auth.login() using the same token, so go straight to verification!
    if (result.needsEmailVerification) {
      setState(() => _loading = false);
      openSignupVerification(context, email);
      return;
    }

    setState(() {
      _loading = false;
      _error = result.message;
    });
  }

  Future<void> _handleGuestLogin() async {
    final token = _captchaToken;
    if (token == null) {
      setState(
        () => _error = 'Please complete the security verification first.',
      );
      return;
    }

    final proceed = await ConfirmDialog.show(
      context,
      icon: Icons.person_outline_rounded,
      title: 'Continue as guest?',
      message: 'You can use the app normally, but your scan history will only be saved on this device. If you uninstall the app, your history will be lost.',
      confirmLabel: 'Yes, continue',
      cancelLabel: 'No',
    );

    if (proceed == true) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = true;
        _error = null;
      });

      await context.read<AuthProvider>().signInAsGuest(token);

      if (!mounted) {
        return;
      }

      _captchaController.reset();
      setState(() => _loading = false);

      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.home,
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bool canGoBack = Navigator.canPop(context);
    final bool alreadySignedIn = context.watch<AuthProvider>().isSignedIn;
    final bool canSubmit = !_loading && _captchaToken != null;

    return AuthScaffold(
      title: 'Welcome Back',
      subtitle: 'Log in to continue scanning.',
      showBack: canGoBack,
      children: [
        if (_error != null) ...[
          ErrorBanner(message: _error!),
          const SizedBox(height: 16),
        ],
        Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              children: [
                AppTextField(
                  key: const Key('field-login-email'),
                  controller: _email,
                  label: 'Email',
                  hint: 'you@example.com',
                  icon: Icons.mail_outline,
                  keyboardType: TextInputType.emailAddress,
                  validator: Validators.email,
                  autofillHints: const [AutofillHints.email],
                  enabled: !_loading,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  key: const Key('field-login-password'),
                  controller: _password,
                  label: 'Password',
                  hint: 'Your password',
                  icon: Icons.lock_outline,
                  isPassword: true,
                  textInputAction: TextInputAction.done,
                  validator: Validators.passwordRequired,
                  autofillHints: const [AutofillHints.password],
                  onSubmitted: (_) {
                    if (canSubmit) {
                      _submit();
                    }
                  },
                  enabled: !_loading,
                ),
              ],
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _loading
                ? null
                : () => Navigator.pushNamed(context, AppRoutes.forgotPassword),
            child: Text('Forgot password?', style: TextStyle(color: c.gold)),
          ),
        ),
        AgreementField(
          agreed: _agreed,
          showError: _agreementError,
          onChanged: (value) {
            if (!mounted) {
              return;
            }
            setState(() {
              _agreed = value;
              if (value) {
                _agreementError = false;
              }
            });
          },
        ),
        const SizedBox(height: 16),
        HCaptchaBox(
          controller: _captchaController,
          onTokenChanged: (token) {
            if (!mounted) {
              return;
            }
            setState(() {
              _captchaToken = token;
              if (token != null) {
                _error = null;
              }
            });
          },
        ),
        const SizedBox(height: 16),
        GoldButton(
          key: const Key('btn-login'),
          label: 'Log In',
          loading: _loading,
          onPressed: canSubmit ? _submit : null,
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                "Don't have an account?",
                style: TextStyle(color: c.textSecondary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              onPressed: _loading
                  ? null
                  : () => Navigator.pushNamed(context, AppRoutes.register),
              child: Text(
                'Create one',
                style: TextStyle(color: c.gold, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        if (!alreadySignedIn) ...[
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: canSubmit ? _handleGuestLogin : null,
              child: Text(
                'Sign in as a guest',
                style: TextStyle(
                  color: canSubmit
                      ? c.textMuted
                      : c.textMuted.withValues(alpha: 0.4),
                  decoration: TextDecoration.underline,
                  decorationColor: canSubmit
                      ? c.textMuted
                      : c.textMuted.withValues(alpha: 0.4),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}
