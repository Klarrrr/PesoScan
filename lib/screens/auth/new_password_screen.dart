import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_routes.dart';
import '../../core/validators.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/auth_scaffold.dart';
import '../../widgets/gold_button.dart';

/// Choose a new password right after "forgot password" (the emailed code was
/// just verified). Changing the password from Settings is a different
/// screen: ChangePasswordScreen.
class NewPasswordScreen extends StatefulWidget {
  const NewPasswordScreen({super.key});

  @override
  State<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends State<NewPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await context.read<AuthProvider>().updatePassword(
      _password.text,
    );
    if (!mounted) return;

    if (result.ok) {
      messenger.showSnackBar(const SnackBar(content: Text('Password updated')));
      navigator.pushNamedAndRemoveUntil(AppRoutes.home, (_) => false);
      return;
    }
    setState(() {
      _loading = false;
      _error = result.message;
    });
  }

  /// Leave the reset without changing anything: log out and go to Login.
  Future<void> _cancel() async {
    final navigator = Navigator.of(context);
    await context.read<AuthProvider>().logout();
    navigator.pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    // The Back button counts as Cancel, so a half-done reset never lingers.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_loading) _cancel();
      },
      child: AuthScaffold(
        title: 'Choose a New Password',
        subtitle: 'Use at least 8 characters with letters and numbers.',
        children: [
          if (_error != null) ...[
            ErrorBanner(message: _error!),
            const SizedBox(height: 16),
          ],
          Form(
            key: _formKey,
            child: Column(
              children: [
                AppTextField(
                  controller: _password,
                  label: 'New password',
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
                  label: 'Confirm new password',
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
          const SizedBox(height: 24),
          GoldButton(
            label: 'Save Password',
            loading: _loading,
            onPressed: _submit,
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: _loading ? null : _cancel,
              child: Text('Cancel', style: TextStyle(color: c.textMuted)),
            ),
          ),
        ],
      ),
    );
  }
}
