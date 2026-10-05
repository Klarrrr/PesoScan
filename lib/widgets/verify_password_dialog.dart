import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../services/auth_result.dart';
import 'app_text_field.dart';
import 'auth_scaffold.dart' show ErrorBanner;
import 'gold_button.dart';

/// "Enter your password to continue". The password is checked by [verify];
/// a wrong password shows a message and the dialog stays open.
class VerifyPasswordDialog extends StatefulWidget {
  final Future<AuthResult> Function(String password) verify;
  final String title;
  final String message;
  final String confirmLabel;

  const VerifyPasswordDialog({
    super.key,
    required this.verify,
    required this.title,
    required this.message,
    this.confirmLabel = 'Confirm',
  });

  /// Returns true only if the password was correct.
  static Future<bool> show(
    BuildContext context, {
    required Future<AuthResult> Function(String password) verify,
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => VerifyPasswordDialog(
        verify: verify,
        title: title,
        message: message,
        confirmLabel: confirmLabel,
      ),
    );
    return result ?? false;
  }

  @override
  State<VerifyPasswordDialog> createState() => _VerifyPasswordDialogState();
}

class _VerifyPasswordDialogState extends State<VerifyPasswordDialog> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (_controller.text.isEmpty) {
      setState(() => _error = 'Please type your password.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });

    final result = await widget.verify(_controller.text);
    if (!mounted) return;

    if (result.ok) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      _busy = false;
      _error = result.message;
    });
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;

    return Dialog(
      backgroundColor: c.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.gold.withValues(alpha: 0.14),
                ),
                child: Icon(
                  Icons.lock_outline_rounded,
                  color: c.gold,
                  size: 30,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: text.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              widget.message,
              textAlign: TextAlign.center,
              style: text.bodyMedium,
            ),
            const SizedBox(height: 18),
            if (_error != null) ...[
              ErrorBanner(message: _error!),
              const SizedBox(height: 14),
            ],
            AppTextField(
              key: const Key('verify-password-field'),
              controller: _controller,
              label: 'Password',
              hint: 'Your password',
              icon: Icons.lock_outline,
              isPassword: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              enabled: !_busy,
            ),
            const SizedBox(height: 20),
            GoldButton(
              label: widget.confirmLabel,
              loading: _busy,
              onPressed: _submit,
            ),
            const SizedBox(height: 10),
            SoftButton(
              label: 'Cancel',
              onPressed: _busy ? null : () => Navigator.pop(context, false),
            ),
          ],
        ),
      ),
    );
  }
}
