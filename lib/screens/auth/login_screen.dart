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
import '../../widgets/confirm_dialog.dart'; // Added for the guest confirmation bubble
import '../../widgets/gold_button.dart';
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
  bool _loading = false;
  bool _agreed = false;
  bool _agreementError = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Someone who already agreed on this phone does not have to tick again.
    TermsConsent.isAccepted().then((accepted) {
      if (mounted && accepted) setState(() => _agreed = true);
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
    if (!formOk || !_agreed) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    final auth = context.read<AuthProvider>();
    final email = _email.text.trim().toLowerCase();
    final result = await auth.login(email: email, password: _password.text);
    if (!mounted) return;

    if (result.ok) {
      await TermsConsent.accept();
      if (!mounted) return;
      setState(() => _loading = false);
      openLoginCode(context, email); // the emailed 2-step code comes next
      return;
    }

    // Account exists but the email was never verified: resend the code.
    if (result.needsEmailVerification) {
      await auth.resendSignupCode(email);
      if (!mounted) return;
      setState(() => _loading = false);
      openSignupVerification(context, email);
      return;
    }

    setState(() {
      _loading = false;
      _error = result.message;
    });
  }

  // --- NEW: Guest Login Handler ---
  Future<void> _handleGuestLogin(BuildContext context) async {
    final proceed = await ConfirmDialog.show(
      context,
      icon: Icons.person_outline_rounded,
      title: 'Continue as guest?',
      message: 'You can use the app normally, but your scan history will only be saved on this device. If you uninstall the app, your history will be lost.',
      confirmLabel: 'Yes, continue',
      cancelLabel: 'No',
    );

    if (proceed == true) {
      if (!context.mounted) return;

      setState(() {
        _loading = true;
        _error = null;
      });

      // 1. Trigger the guest login in your AuthProvider
      await context.read<AuthProvider>().signInAsGuest();

      if (!context.mounted) return;

      // 2. Stop the loading spinner
      setState(() => _loading = false);

      // 3. Navigate to the main app screen and clear the back button history
      // Note: If your main app route is named something else, change AppRoutes.home
      // to match your setup (e.g., AppRoutes.main or AppRoutes.dashboard)
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

    // Check if the user came from the Settings tab
    final bool cameFromSettings = Navigator.canPop(context);

    return AuthScaffold(
      title: 'Welcome Back',
      subtitle: 'Log in to continue scanning.',
      showBack: cameFromSettings,
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
                  onSubmitted: (_) => _submit(),
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
            if (!mounted) return;
            setState(() {
              _agreed = value;
              if (value) _agreementError = false;
            });
          },
        ),
        const SizedBox(height: 16),
        GoldButton(
          key: const Key('btn-login'),
          label: 'Log In',
          loading: _loading,
          onPressed: _submit,
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

        // --- MODIFIED: Only show Guest button if they are NOT coming from Settings ---
        if (!cameFromSettings) ...[
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: _loading ? null : () => _handleGuestLogin(context),
              child: Text(
                'Sign in as a guest',
                style: TextStyle(
                  color: c.textMuted,
                  decoration: TextDecoration.underline,
                  decorationColor: c.textMuted,
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
