import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_images.dart';
import '../../core/app_routes.dart';
import '../../services/permission_service.dart';
import '../../widgets/app_image.dart';
import '../../widgets/gold_button.dart';

/// Page 2 of the prototype. Explains WHY we need the camera, then asks.
/// "Not Now" is allowed: the scanner shows a popup later (Part 9).
class CameraPermissionScreen extends StatefulWidget {
  const CameraPermissionScreen({super.key});

  @override
  State<CameraPermissionScreen> createState() => _CameraPermissionScreenState();
}

// WidgetsBindingObserver tells us when the app returns from Android Settings.
class _CameraPermissionScreenState extends State<CameraPermissionScreen>
    with WidgetsBindingObserver {
  CameraAccess? _access; // null while checking
  bool _leaving = false; // prevents navigating twice

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    final access = await PermissionService.cameraStatus();
    if (!mounted) return;
    if (access == CameraAccess.granted) {
      _next();
      return;
    }
    setState(() => _access = access);
  }

  Future<void> _request() async {
    final access = await PermissionService.requestCamera();
    if (!mounted) return;
    if (access == CameraAccess.granted) {
      _next();
      return;
    }
    setState(() => _access = access);
  }

  /// Prototype order: permission -> onboarding.
  void _next() {
    if (_leaving) return;
    _leaving = true;
    Navigator.pushReplacementNamed(context, AppRoutes.onboarding);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;

    if (_access == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // After two refusals Android won't show the popup again: only Settings can help.
    final blocked = _access == CameraAccess.permanentlyDenied;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: c.chip,
                            border: Border.all(
                              color: c.gold.withValues(alpha: 0.25),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: AppImage(
                            AppImages.cameraAccess,
                            width: 44,
                            height: 44,
                            fallback: Icon(
                              blocked
                                  ? Icons.no_photography_outlined
                                  : Icons.photo_camera_outlined,
                              size: 36,
                              color: c.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          blocked
                              ? 'Camera Access Blocked'
                              : 'Camera Access Required',
                          textAlign: TextAlign.center,
                          style: text.headlineSmall,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          blocked
                              ? 'Open Settings, tap Permissions, then Camera, '
                                    'and choose Allow for PesoScan. Then come back.'
                              : 'PesoScan needs access to your camera to detect '
                                    'and count Philippine coins and bills in real time.',
                          textAlign: TextAlign.center,
                          style: text.bodyLarge,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Your images are processed locally on your device. '
                          'No photos are uploaded or stored externally.',
                          textAlign: TextAlign.center,
                          style: text.bodyMedium?.copyWith(color: c.textMuted),
                        ),
                        const SizedBox(height: 40),
                        GoldButton(
                          label: blocked
                              ? 'Open Settings'
                              : 'Allow Camera Access',
                          onPressed: blocked
                              ? PermissionService.openSettings
                              : _request,
                        ),
                        const SizedBox(height: 12),
                        SoftButton(label: 'Not Now', onPressed: _next),
                      ],
                    ),
                  ),
                ),
              ),
              Text(
                'You can update permissions anytime in your device Settings.',
                textAlign: TextAlign.center,
                style: text.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
