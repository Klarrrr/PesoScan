import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Our own simple version of the camera permission state.
enum CameraAccess { granted, denied, permanentlyDenied }

/// What a refused camera permission means. Android cannot tell "never asked"
/// from "asked, and the user chose 'don't ask again'", so we combine:
///  - did WE ask before?
///  - would Android still show its popup (the "rationale" flag)?
CameraAccess denialKind({
  required bool askedBefore,
  required bool canAskAgain,
}) {
  if (!askedBefore || canAskAgain) return CameraAccess.denied;
  return CameraAccess.permanentlyDenied;
}

/// The three things the screens need. Behind an interface so the screens can
/// be tested without a phone.
abstract class CameraPermissions {
  Future<CameraAccess> status();
  Future<CameraAccess> request();
  Future<void> openSettings();
}

class PlatformCameraPermissions implements CameraPermissions {
  @override
  Future<CameraAccess> status() => PermissionService.cameraStatus();

  @override
  Future<CameraAccess> request() => PermissionService.requestCamera();

  @override
  Future<void> openSettings() async {
    await PermissionService.openSettings();
  }
}

/// Wraps the permission packages so screens never touch them directly.
class PermissionService {
  PermissionService._();

  static const _askedKey = 'camera_permission_asked';

  static Future<bool> _askedBefore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_askedKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _rememberAsked() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_askedKey, true);
    } catch (_) {
      // Not important enough to fail over.
    }
  }

  /// Check WITHOUT showing any popup.
  static Future<CameraAccess> cameraStatus() async {
    final status = await Permission.camera.status;
    if (status.isGranted || status.isLimited) return CameraAccess.granted;
    if (status.isPermanentlyDenied || status.isRestricted) {
      return CameraAccess.permanentlyDenied;
    }
    return _classifyDenied();
  }

  static Future<CameraAccess> _classifyDenied() async {
    final asked = await _askedBefore();
    final canAskAgain = await Permission.camera.shouldShowRequestRationale;
    return denialKind(askedBefore: asked, canAskAgain: canAskAgain);
  }

  /// Show Android's own popup ("Allow PesoScan to take pictures?").
  ///
  /// IMPORTANT: this asks through the CAMERA plugin, not through
  /// permission_handler. permission_handler never answers when Android shows
  /// no popup (a blocked permission), and then refuses every later request.
  /// The camera plugin always answers.
  static Future<CameraAccess> requestCamera() async {
    await _rememberAsked();

    CameraController? controller;
    try {
      final cameras = await availableCameras();
      // "await" in every return below: the answer must be finished BEFORE the
      // catch/finally code runs, and errors must be caught right here.
      if (cameras.isEmpty) {
        return await cameraStatus();
      }
      // not a permission problem

      controller = CameraController(
        cameras.first,
        ResolutionPreset.low,
        enableAudio: false,
      );
      await controller.initialize(); // this is the step that asks
      return CameraAccess.granted;
    } on CameraException catch (e) {
      debugPrint('Camera permission request: ${e.code}');
      if (e.code.startsWith('CameraAccess')) return await _classifyDenied();
      return await cameraStatus(); // some other camera problem: the scanner explains it
    } catch (e) {
      debugPrint('Camera permission request failed: $e');
      return await cameraStatus();
    } finally {
      try {
        await controller?.dispose();
      } catch (_) {}
    }
  }

  /// Open this app's page in Android Settings.
  static Future<bool> openSettings() async {
    return await openAppSettings();
  }
}
