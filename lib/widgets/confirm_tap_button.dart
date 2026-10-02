import 'dart:async';

import 'package:flutter/material.dart';

/// "Tap once to arm, tap again to confirm." Disarms itself after [timeout].
/// You draw it with [builder], so it can be a pill, a button, anything.
class ConfirmTapButton extends StatefulWidget {
  final Widget Function(BuildContext context, bool armed) builder;
  final VoidCallback onConfirmed;
  final Duration timeout;

  const ConfirmTapButton({
    super.key,
    required this.builder,
    required this.onConfirmed,
    this.timeout = const Duration(seconds: 3),
  });

  @override
  State<ConfirmTapButton> createState() => _ConfirmTapButtonState();
}

class _ConfirmTapButtonState extends State<ConfirmTapButton> {
  bool _armed = false;
  Timer? _timer;

  void _onTap() {
    if (!_armed) {
      setState(() => _armed = true);
      _timer = Timer(widget.timeout, () {
        if (mounted) setState(() => _armed = false);
      });
      return;
    }
    _timer?.cancel();
    setState(() => _armed = false);
    widget.onConfirmed();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _onTap,
      child: widget.builder(context, _armed),
    );
  }
}
