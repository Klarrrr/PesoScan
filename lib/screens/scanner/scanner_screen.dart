import 'dart:io' show Platform;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_theme.dart';
import '../../providers/scanner_provider.dart';
import '../../services/detector/detector_factory.dart';
import '../../services/detector/money_detector.dart';
import '../../services/permission_service.dart';
import 'detection_overlay.dart';
import 'scanner_widgets.dart';

/// Pages 7-8 of the prototype: live camera + detections + live total.
class ScannerScreen extends StatelessWidget {
  const ScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      // `..start()` loads the detector right after creating the provider.
      create: (_) =>
          ScannerProvider(detector: DetectorFactory.create())..start(),
      // The scanner is always dark, whatever theme the app uses.
      child: Theme(data: AppTheme.dark, child: const _ScannerView()),
    );
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
  bool _streaming = false;
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
        ResolutionPreset.high,
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
      await _startStream(controller);
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

  /// Hand every camera frame to the scanner provider.
  Future<void> _startStream(CameraController controller) async {
    final scanner = context.read<ScannerProvider>();
    try {
      await controller.startImageStream((CameraImage image) {
        scanner.onFrame(
          DetectorFrame(width: image.width, height: image.height, raw: image),
        );
      });
      _streaming = true;
    } catch (e) {
      debugPrint('Could not start the image stream: $e');
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
    try {
      if (_streaming) await controller.stopImageStream();
    } catch (_) {}
    _streaming = false;
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

  /// Width / height of the UPRIGHT frame. previewSize is landscape, so
  /// the portrait aspect is height / width.
  double get _frameAspect {
    final size = _controller?.value.previewSize;
    if (size == null || size.width == 0) return 9 / 16;
    return size.height / size.width;
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
                // Only the overlays rebuild ~10x per second, not the camera.
                Consumer<ScannerProvider>(
                  builder: (context, scanner, _) => DetectionOverlay(
                    detections: scanner.detections,
                    frameAspect: _frameAspect,
                  ),
                ),
                CornerBrackets(topInset: MediaQuery.paddingOf(context).top + 8),
                ScanLine(animation: _scanLine),
                if (hasCamera)
                  Consumer<ScannerProvider>(
                    builder: (context, scanner, _) => Align(
                      alignment: const Alignment(0, 0.78),
                      child: scanner.count == 0
                          ? const HintChip(
                              text: 'Place coins or bills in frame',
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    bottom: false,
                    child: Consumer<ScannerProvider>(
                      builder: (context, scanner, _) => ScannerTopBar(
                        onBack: () => Navigator.pop(context),
                        live: scanner.isLive,
                        count: scanner.count,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Consumer<ScannerProvider>(
            builder: (context, scanner, _) => TotalPanel(
              totalCentavos: scanner.totalCentavos,
              count: scanner.count,
            ),
          ),
          Consumer<ScannerProvider>(
            builder: (context, scanner, _) => ScannerControlBar(
              torchOn: _torchOn,
              onTorch: _toggleTorch,
              captureEnabled: scanner.isLive,
              onCapture: scanner.isLive
                  ? () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Freeze and the result sheet arrive in Part 11.',
                        ),
                      ),
                    )
                  : null,
              onReset: scanner.reset,
            ),
          ),
        ],
      ),
    );
  }
}
