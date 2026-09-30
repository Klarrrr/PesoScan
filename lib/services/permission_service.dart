import 'package:permission_handler/permission_handler.dart';

/// Our own simple version of the camera permission state.
enum CameraAccess { granted, denied, permanentlyDenied }

/// Wraps the permission_handler package so screens never touch it directly.
/// (If the package changes, we fix ONE file.)
class PermissionService {
  PermissionService._();

  /// Check without showing any popup.
  static Future<CameraAccess> cameraStatus() async {
    return _map(await Permission.camera.status);
  }

  /// Show the system popup ("Allow PesoScan to take pictures?").
  static Future<CameraAccess> requestCamera() async {
    return _map(await Permission.camera.request());
  }

  /// Open this app's page in Android Settings.
  static Future<bool> openSettings() => openAppSettings();

  static CameraAccess _map(PermissionStatus status) {
    if (status.isGranted || status.isLimited) return CameraAccess.granted;
    // Android says "permanently denied" after the user refuses twice
    // (or picks "Don't ask again"). Only Settings can fix it from then on.
    if (status.isPermanentlyDenied || status.isRestricted) {
      return CameraAccess.permanentlyDenied;
    }
    return CameraAccess.denied;
  }
}
