import 'package:flutter/material.dart';

import '../../core/app_routes.dart';
import '../../services/permission_service.dart';
import '../../widgets/camera_required_dialog.dart';

/// Makes sure the camera is allowed. Returns true when it can be used.
///
///  - allowed:        returns true at once
///  - never allowed:  our popup, then Android's popup
///  - blocked:        our popup that opens Settings (no request at all:
///                    Android would not show anything)
///
/// It asks AT MOST ONCE per tap. After a "no" it shows a message and stops:
/// no popup loops.
Future<bool> ensureCameraAccess(
  BuildContext context, {
  CameraPermissions? permissions, // tests pass a fake
}) async {
  final gateway = permissions ?? PlatformCameraPermissions();
  final messenger = ScaffoldMessenger.of(context);

  var access = await gateway.status();
  if (access == CameraAccess.granted) return true;
  if (!context.mounted) return false;

  final wantsToContinue = await CameraRequiredDialog.show(
    context,
    blocked: access == CameraAccess.permanentlyDenied,
  );
  if (!wantsToContinue) return false;

  // Android will not show its popup any more: only Settings can help.
  if (access == CameraAccess.permanentlyDenied) {
    await gateway.openSettings();
    return false;
  }

  access = await gateway.request();
  if (access == CameraAccess.granted) return true;

  messenger.showSnackBar(
    SnackBar(
      content: Text(
        access == CameraAccess.permanentlyDenied
            ? 'Camera access is blocked.'
            : 'The camera is needed to scan coins and bills.',
      ),
      action: access == CameraAccess.permanentlyDenied
          ? SnackBarAction(label: 'Settings', onPressed: gateway.openSettings)
          : null,
    ),
  );
  return false;
}

/// Every "start scanning" button calls this one function.
Future<void> openScanner(BuildContext context) async {
  if (!await ensureCameraAccess(context)) return;
  if (context.mounted) await Navigator.pushNamed(context, AppRoutes.scanner);
}
