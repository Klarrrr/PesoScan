import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_theme.dart';
import 'gold_button.dart';

/// A "Are you sure?" popup in the app's style.
/// Returns true only if the user pressed the main button.
class ConfirmDialog extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String confirmLabel;
  final bool danger;

  const ConfirmDialog({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.confirmLabel,
    this.danger = false,
  });

  static Future<bool> show(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String message,
    required String confirmLabel,
    bool danger = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmDialog(
        icon: icon,
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        danger: danger,
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
      child: Padding(
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
            const SizedBox(height: 10),
            SoftButton(
              label: 'Cancel',
              onPressed: () => Navigator.pop(context, false),
            ),
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
