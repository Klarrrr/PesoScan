import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/validators.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/auth_scaffold.dart';
import '../../widgets/gold_button.dart';
import 'auth_flows.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
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
    final result = await context.read<AuthProvider>().forgotPassword(email);
    if (!mounted) return;

    setState(() {
      _loading = false;
      if (!result.ok) _error = result.message;
    });
    if (result.ok) openRecoveryCode(context, email);
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Forgot Password?',
      subtitle:
          'Enter your email and we will send you a 6-digit code '
          'to reset your password.',
      showBack: true,
      children: [
        if (_error != null) ...[
          ErrorBanner(message: _error!),
          const SizedBox(height: 16),
        ],
        Form(
          key: _formKey,
          child: AppTextField(
            controller: _email,
            label: 'Email',
            hint: 'you@example.com',
            icon: Icons.mail_outline,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            validator: Validators.email,
            autofillHints: const [AutofillHints.email],
            onSubmitted: (_) => _submit(),
            enabled: !_loading,
          ),
        ),
        const SizedBox(height: 24),
        GoldButton(label: 'Send Code', loading: _loading, onPressed: _submit),
      ],
    );
  }
}
