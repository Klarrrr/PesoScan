import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import 'gold_button.dart';

/// The popup shown when the user taps Scan without camera permission.
class CameraRequiredDialog extends StatelessWidget {
  /// True when Android will no longer show its own popup,
  /// so the only way forward is the Settings app.
  final bool blocked;
  const CameraRequiredDialog({super.key, required this.blocked});

  /// Returns true if the user chose the main button.
  static Future<bool> show(
    BuildContext context, {
    required bool blocked,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => CameraRequiredDialog(blocked: blocked),
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
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.chip,
                border: Border.all(color: c.gold.withValues(alpha: 0.25)),
              ),
              child: Icon(
                blocked
                    ? Icons.no_photography_outlined
                    : Icons.photo_camera_outlined,
                color: c.textPrimary,
                size: 30,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Camera Access Required',
              textAlign: TextAlign.center,
              style: text.titleLarge,
            ),
            const SizedBox(height: 10),
            Text(
              blocked
                  ? 'Camera access is turned off for PesoScan. Open Settings, '
                        'tap Permissions, then Camera, and choose Allow.'
                  : 'PesoScan needs your camera to detect and count coins and '
                        'bills. Please allow camera access to start scanning.',
              textAlign: TextAlign.center,
              style: text.bodyMedium,
            ),
            const SizedBox(height: 22),
            GoldButton(
              label: blocked ? 'Open Settings' : 'Allow Camera',
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
