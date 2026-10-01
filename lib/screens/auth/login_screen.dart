import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_routes.dart';
import '../../core/validators.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/auth_scaffold.dart';
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
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    final auth = context.read<AuthProvider>();
    final email = _email.text.trim().toLowerCase();
    final result = await auth.login(email: email, password: _password.text);
    if (!mounted) return;

    if (result.ok) {
      setState(() => _loading = false);
      _onPasswordAccepted(email);
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

  /// TEMPORARY (Part 5): go straight in.
  /// Part 6 replaces this with the emailed-code step.
  /// The password was correct and the emailed code has been sent.
  void _onPasswordAccepted(String email) {
    openLoginCode(context, email);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return AuthScaffold(
      title: 'Welcome Back',
      subtitle: 'Log in to continue scanning.',
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
        const SizedBox(height: 8),
        GoldButton(label: 'Log In', loading: _loading, onPressed: _submit),
        const SizedBox(height: 20),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              "Don't have an account?",
              style: TextStyle(color: c.textSecondary),
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
      ],
    );
  }
}
