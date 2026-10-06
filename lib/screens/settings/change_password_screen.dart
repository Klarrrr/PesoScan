import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/validators.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/auth_scaffold.dart';
import '../../widgets/gold_button.dart';

/// Change the password while logged in (opened from Settings).
/// It asks for the current password first, and it NEVER signs you out:
/// Cancel and Back simply return to Settings.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    // Read what we need BEFORE the first await.
    final auth = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await auth.changePassword(
      currentPassword: _current.text,
      newPassword: _new.text,
    );
    if (!mounted) return;

    if (result.ok) {
      messenger.showSnackBar(const SnackBar(content: Text('Password updated')));
      navigator.pop(); // back to Settings, still signed in
      return;
    }
    setState(() {
      _loading = false;
      _error = result.message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return AuthScaffold(
      title: 'Change Password',
      subtitle: 'Enter your current password, then choose a new one.',
      showBack: true,
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
                key: const Key('field-current'),
                controller: _current,
                label: 'Current password',
                hint: 'Your current password',
                icon: Icons.lock_outline,
                isPassword: true,
                validator: Validators.passwordRequired,
                enabled: !_loading,
              ),
              const SizedBox(height: 16),
              AppTextField(
                key: const Key('field-new'),
                controller: _new,
                label: 'New password',
                hint: 'At least 8 characters',
                icon: Icons.lock_outline,
                isPassword: true,
                validator: (v) {
                  final basic = Validators.newPassword(v);
                  if (basic != null) return basic;
                  return v == _current.text
                      ? 'Choose a different password'
                      : null;
                },
                enabled: !_loading,
              ),
              const SizedBox(height: 16),
              AppTextField(
                key: const Key('field-confirm'),
                controller: _confirm,
                label: 'Confirm new password',
                hint: 'Type it again',
                icon: Icons.lock_outline,
                isPassword: true,
                textInputAction: TextInputAction.done,
                validator: (v) => Validators.confirmPassword(v, _new.text),
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
            key: const Key('btn-cancel'),
            onPressed: _loading ? null : () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: c.textMuted)),
          ),
        ),
      ],
    );
  }
}
