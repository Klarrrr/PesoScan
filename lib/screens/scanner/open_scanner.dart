import 'package:flutter/material.dart';

import '../../core/app_routes.dart';
import '../../services/permission_service.dart';
import '../../widgets/camera_required_dialog.dart';

/// Every "start scanning" button calls this one function.
/// Opens the scanner if the camera is allowed; otherwise explains why it
/// is needed (the popup), asks again, and keeps asking until the user
/// either allows it or cancels.
Future<void> openScanner(BuildContext context) async {
  while (true) {
    final access = await PermissionService.cameraStatus();

    if (access == CameraAccess.granted) {
      if (context.mounted) {
        await Navigator.pushNamed(context, AppRoutes.scanner);
      }
      return;
    }

    if (!context.mounted) return;
    final wantsToContinue = await CameraRequiredDialog.show(
      context,
      blocked: access == CameraAccess.permanentlyDenied,
    );
    if (!wantsToContinue) return;

    if (access == CameraAccess.permanentlyDenied) {
      // Android won't show its popup any more: go to Settings.
      // The user taps Scan again when they come back.
      await PermissionService.openSettings();
      return;
    }

    await PermissionService.requestCamera();
    // Loop: if allowed we open the scanner, if denied we show the popup again.
    if (!context.mounted) return;
  }
}
