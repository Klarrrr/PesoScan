import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_theme.dart';
import 'gold_button.dart';

/// An "Are you sure?" popup in the app's style.
/// Returns true only if the user pressed the main button.
/// With [showCancel] false it is a plain message with one button.
class ConfirmDialog extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool danger;
  final bool showCancel;

  const ConfirmDialog({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.confirmLabel,
    this.cancelLabel = 'Cancel',
    this.danger = false,
    this.showCancel = true,
  });

  static Future<bool> show(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String message,
    required String confirmLabel,
    String cancelLabel = 'Cancel',
    bool danger = false,
    bool showCancel = true,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmDialog(
        icon: icon,
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        danger: danger,
        showCancel: showCancel,
      ),
    );
    return result ?? false;
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
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (danger ? c.danger : c.gold).withValues(alpha: 0.14),
              ),
              child: Icon(icon, color: danger ? c.danger : c.gold, size: 30),
            ),
            const SizedBox(height: 16),
            Text(title, textAlign: TextAlign.center, style: text.titleLarge),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: text.bodyMedium),
            const SizedBox(height: 22),
            if (danger)
              _DangerButton(
                label: confirmLabel,
                onPressed: () => Navigator.pop(context, true),
              )
            else
              GoldButton(
                label: confirmLabel,
                onPressed: () => Navigator.pop(context, true),
              ),
            if (showCancel) ...[
              const SizedBox(height: 10),
              SoftButton(
                label: cancelLabel,
                onPressed: () => Navigator.pop(context, false),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DangerButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  const _DangerButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: c.danger,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onPressed,
        child: SizedBox(
          height: 56,
          width: double.infinity,
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: AppFonts.heading,
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
