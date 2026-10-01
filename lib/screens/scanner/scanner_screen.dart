import 'dart:io' show Platform;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_theme.dart';
import '../../services/permission_service.dart';
import 'scanner_widgets.dart';

/// Pages 7-8 of the prototype. In Part 9 it shows the live camera and all
/// the chrome; Part 10 adds the detections.
class ScannerScreen extends StatelessWidget {
  const ScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // The scanner is always dark, whatever theme the app uses.
    return Theme(data: AppTheme.dark, child: const _ScannerView());
  }
}

class _ScannerView extends StatefulWidget {
  const _ScannerView();

  @override
  State<_ScannerView> createState() => _ScannerViewState();
}

class _ScannerViewState extends State<_ScannerView>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  CameraController? _controller;
  String? _cameraError;
  bool _permissionProblem = false;
  bool _torchOn = false;
  bool _initializing = false;
  late final AnimationController _scanLine;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scanLine = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scanLine.dispose();
    _controller?.dispose();
    super.dispose();
  }

  // The camera must be released when the app goes to the background
  // and re-opened when it returns.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _stopCamera();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    if (_initializing || _controller != null) return;
    _initializing = true;
    if (mounted) {
      setState(() {
        _cameraError = null;
        _permissionProblem = false;
      });
    }

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _fail('No camera was found on this device.');
        return;
      }
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        back,
        ResolutionPreset.high, // 720p, 16:9
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.yuv420
            : ImageFormatGroup.bgra8888,
      );
      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _torchOn = false;
      });
    } on CameraException catch (e) {
      final denied = e.code.startsWith('CameraAccess');
      _fail(
        denied
            ? 'Camera access is turned off for PesoScan. Allow it in Settings.'
            : 'The camera could not be started (${e.code}).',
        permission: denied,
      );
    } catch (_) {
      _fail('The camera could not be started.');
    } finally {
      _initializing = false;
    }
  }

  void _fail(String message, {bool permission = false}) {
    if (!mounted) return;
    setState(() {
      _cameraError = message;
      _permissionProblem = permission;
    });
  }

  Future<void> _stopCamera() async {
    final controller = _controller;
    if (controller == null) return;
    if (mounted) setState(() => _controller = null);
    await controller.dispose();
  }

  Future<void> _toggleTorch() async {
    final controller = _controller;
    if (controller == null) return;
    try {
      await controller.setFlashMode(_torchOn ? FlashMode.off : FlashMode.torch);
      if (mounted) setState(() => _torchOn = !_torchOn);
    } on CameraException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Flash is not available on this device.')),
      );
    }
  }

  Widget _buildPreview() {
    if (_cameraError != null) {
      return CameraErrorView(
        message: _cameraError!,
        permissionProblem: _permissionProblem,
        onRetry: _initCamera,
        onOpenSettings: PermissionService.openSettings,
      );
    }

    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return Center(
        child: CircularProgressIndicator(color: context.colors.gold),
      );
    }

    // previewSize is reported in landscape, so width and height are swapped
    // for a portrait phone. BoxFit.cover fills the area without stretching.
    final size = controller.value.previewSize!;
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: size.height,
          height: size.width,
          child: CameraPreview(controller),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasCamera = _controller != null && _cameraError == null;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                _buildPreview(),
                const GridOverlay(),
                CornerBrackets(topInset: MediaQuery.paddingOf(context).top + 8),
                ScanLine(animation: _scanLine),
                if (hasCamera)
                  const Align(
                    alignment: Alignment(0, 0.78),
                    child: HintChip(text: 'Place coins or bills in frame'),
                  ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    bottom: false,
                    child: ScannerTopBar(
                      onBack: () => Navigator.pop(context),
                      live: false,
                      count: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const TotalPanel(totalCentavos: 0, count: 0),
          ScannerControlBar(
            torchOn: _torchOn,
            onTorch: _toggleTorch,
            captureEnabled: false, // Part 10 enables it when coins are found
            onCapture: null, // Part 11
            onReset: () {}, // Part 10
          ),
        ],
      ),
    );
  }
}
