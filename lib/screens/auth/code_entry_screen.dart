import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_colors.dart';
import '../../core/app_theme.dart';
import '../../core/validators.dart';
import '../../services/auth_result.dart';
import '../../widgets/auth_scaffold.dart';
import '../../widgets/gold_button.dart';

/// Everything that differs between flows (sign-up, login, password reset)
/// is passed in here, so ONE screen serves them all.
class CodeEntryArgs {
  final String title;
  final String subtitle;
  final Future<AuthResult> Function(String code) onVerify;
  final Future<AuthResult> Function() onResend;
  final void Function(BuildContext context) onSuccess;

  const CodeEntryArgs({
    required this.title,
    required this.subtitle,
    required this.onVerify,
    required this.onResend,
    required this.onSuccess,
  });
}

class CodeEntryScreen extends StatefulWidget {
  final CodeEntryArgs args;
  const CodeEntryScreen({super.key, required this.args});

  @override
  State<CodeEntryScreen> createState() => _CodeEntryScreenState();
}

class _CodeEntryScreenState extends State<CodeEntryScreen> {
  static const _resendSeconds = 60; // matches Supabase's 60-second limit

  final _code = TextEditingController();
  Timer? _timer;
  int _secondsLeft = _resendSeconds;
  bool _busy = false;
  String? _error;
  String? _info;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _secondsLeft = _resendSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_secondsLeft > 0) _secondsLeft--;
      });
      if (_secondsLeft == 0) t.cancel();
    });
  }

  Future<void> _verify() async {
    if (_busy) return; // prevents double submit
    final code = _code.text.trim();
    if (Validators.code(code) != null) {
      setState(() => _error = 'Enter the 6-digit code');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });

    final result = await widget.args.onVerify(code);
    if (!mounted) return;

    if (result.ok) {
      widget.args.onSuccess(context);
      return;
    }
    setState(() {
      _busy = false;
      _error = result.message;
    });
    _code.clear();
  }

  Future<void> _resend() async {
    if (_secondsLeft > 0 || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });

    final result = await widget.args.onResend();
    if (!mounted) return;

    setState(() {
      _busy = false;
      if (result.ok) {
        _info = 'A new code is on its way.';
        _startTimer();
      } else {
        _error = result.message;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;

    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: color, width: width),
        );

    return AuthScaffold(
      title: widget.args.title,
      subtitle: widget.args.subtitle,
      showBack: true,
      children: [
        if (_error != null) ...[
          ErrorBanner(message: _error!),
          const SizedBox(height: 16),
        ],
        if (_info != null) ...[
          ErrorBanner(message: _info!, success: true),
          const SizedBox(height: 16),
        ],
        TextField(
          controller: _code,
          enabled: !_busy,
          autofocus: true,
          maxLength: 6,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          autofillHints: const [AutofillHints.oneTimeCode],
          cursorColor: c.gold,
          style: AppText.mono(
            size: 30,
            color: c.textPrimary,
            letterSpacing: 10,
          ),
          onChanged: (v) {
            if (v.length == 6) _verify(); // submit automatically
          },
          decoration: InputDecoration(
            counterText: '',
            hintText: '000000',
            hintStyle: AppText.mono(
              size: 30,
              color: c.textMuted.withValues(alpha: 0.5),
              letterSpacing: 10,
            ),
            filled: true,
            fillColor: c.surface,
            contentPadding: const EdgeInsets.symmetric(vertical: 18),
            border: border(c.border),
            enabledBorder: border(c.border),
            focusedBorder: border(c.gold, 1.5),
          ),
        ),
        const SizedBox(height: 24),
        GoldButton(label: 'Verify', loading: _busy, onPressed: _verify),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: (_secondsLeft == 0 && !_busy) ? _resend : null,
            child: Text(
              _secondsLeft > 0
                  ? 'Resend code in ${_secondsLeft}s'
                  : 'Resend code',
              style: TextStyle(color: _secondsLeft == 0 ? c.gold : c.textMuted),
            ),
          ),
        ),
        Center(
          child: Text(
            "Can't find it? Check your spam folder.",
            style: text.bodySmall,
          ),
        ),
      ],
    );
  }
}
