import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_theme.dart';

/// The big gold gradient button ("Next", "Get Started", "Allow Camera Access").
class GoldButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const GoldButton({super.key, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final radius = BorderRadius.circular(18);

    return Opacity(
      opacity: onPressed == null ? 0.5 : 1,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            gradient: c.goldGradient,
            borderRadius: radius,
          ),
          child: InkWell(
            borderRadius: radius,
            onTap: onPressed,
            child: SizedBox(
              height: 56,
              width: double.infinity,
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: c.onGold,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The dark secondary button ("Not Now", "Discard").
class SoftButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const SoftButton({super.key, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final radius = BorderRadius.circular(18);

    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: radius,
          border: Border.all(color: c.border),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onPressed,
          child: SizedBox(
            height: 56,
            width: double.infinity,
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: AppFonts.heading,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: c.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
