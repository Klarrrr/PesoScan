import 'package:flutter/material.dart';

/// Shown in RELEASE builds instead of Flutter's grey error box, when a
/// widget fails to build. It uses no theme, so it works even when the
/// failure is in the theme itself.
class FriendlyErrorView extends StatelessWidget {
  const FriendlyErrorView({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        color: const Color(0xFF0A1226),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: Color(0xFFF5B83D),
              size: 40,
            ),
            SizedBox(height: 12),
            Text(
              'Something went wrong',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFFF2F4F8),
                fontSize: 16,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.none,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Please go back and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF7C8DB5),
                fontSize: 13,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
