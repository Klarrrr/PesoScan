import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/validators.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/auth_scaffold.dart';
import '../../widgets/gold_button.dart';
import 'auth_flows.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    final email = _email.text.trim().toLowerCase();
    final result = await context.read<AuthProvider>().register(
      username: _username.text.trim(),
      email: email,
      password: _password.text,
    );
    if (!mounted) return;

    setState(() {
      _loading = false;
      if (!result.ok) _error = result.message;
    });
    if (result.ok) openSignupVerification(context, email);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;

    return AuthScaffold(
      title: 'Create Account',
      subtitle: 'Sign up to start counting your coins and bills.',
      showBack: true,
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
                  controller: _username,
                  label: 'Username',
                  hint: 'juan_delacruz',
                  icon: Icons.person_outline,
                  validator: Validators.username,
                  autofillHints: const [AutofillHints.newUsername],
                  enabled: !_loading,
                ),
                const SizedBox(height: 16),
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
                  hint: 'At least 8 characters',
                  icon: Icons.lock_outline,
                  isPassword: true,
                  validator: Validators.newPassword,
                  autofillHints: const [AutofillHints.newPassword],
                  enabled: !_loading,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _confirm,
                  label: 'Confirm password',
                  hint: 'Type it again',
                  icon: Icons.lock_outline,
                  isPassword: true,
                  textInputAction: TextInputAction.done,
                  validator: (v) =>
                      Validators.confirmPassword(v, _password.text),
                  onSubmitted: (_) => _submit(),
                  enabled: !_loading,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Use letters and numbers. By creating an account you agree to '
          'the Terms of Service and Privacy Policy.',
          style: text.bodySmall,
        ),
        const SizedBox(height: 20),
        GoldButton(
          label: 'Create Account',
          loading: _loading,
          onPressed: _submit,
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Already have an account?',
              style: TextStyle(color: c.textSecondary),
            ),
            TextButton(
              onPressed: _loading ? null : () => Navigator.pop(context),
              child: Text(
                'Log in',
                style: TextStyle(color: c.gold, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
