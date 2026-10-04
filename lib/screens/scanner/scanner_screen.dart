import 'dart:io' show Platform;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_theme.dart';
import '../../core/constants.dart';
import '../../models/detection.dart';
import '../../providers/auth_provider.dart';
import '../../providers/history_provider.dart';
import '../../providers/scanner_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/detector/detector_factory.dart';
import '../../services/detector/money_detector.dart';
import '../../services/feedback_service.dart';
import '../../services/frame_analyzer.dart';
import '../../services/permission_service.dart';
import '../../services/scan_image_store.dart';
import '../../services/scan_saver.dart';
import '../../widgets/confirm_dialog.dart';
import 'detection_overlay.dart';
import 'guidance_widgets.dart';
import 'problem_widgets.dart';
import 'scan_result_sheet.dart';
import 'scanner_widgets.dart';

/// Pages 7-9 of the prototype: live camera, detections, capture and result,
/// scanning tips, and clear messages when something is wrong.
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
  final ScanImageStore _imageStore = ScanImageStore();
  final FrameAnalyzer _analyzer = FrameAnalyzer();
  DateTime _lastAnalysis = DateTime.fromMillisecondsSinceEpoch(0);

  CameraController? _controller;
  int _rotation = 0; // degrees to turn the camera picture so it looks upright
  String? _cameraError;
  bool _permissionProblem = false;
  bool _torchOn = false;
  bool _initializing = false;
  bool _streaming = false;
  bool _capturing = false;
  late final AnimationController _scanLine;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scanLine = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);

    // Vibrate and ding when a coin or bill is locked in.
    context.read<ScannerProvider>().onItemsLocked = (_) {
      if (!mounted) return;
      final settings = context.read<SettingsProvider>();
      FeedbackService.instance.itemLocked(
        haptic: settings.hapticEnabled,
        audio: settings.audioEnabled,
      );
    };

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

  // ---------------------------------------------------------------
  // Camera
  // ---------------------------------------------------------------

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

      // Start with the flash definitely OFF. Some phones default to "auto",
      // which would fire the flash when we take the photo.
      try {
        await controller.setFlashMode(FlashMode.off);
      } catch (_) {
        // This phone has no flash: nothing to switch off.
      }

      // The screen may have been closed while we waited above.
      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _rotation = back.sensorOrientation;
        _torchOn = false;
      });
      context.read<ScannerProvider>().frameAspect = _frameAspect;
      _analyzer.reset();
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

  /// Hand every camera frame to the detector, and every few to the analyzer.
  Future<void> _startStream(CameraController controller) async {
    if (_streaming || !mounted) return;
    final scanner = context.read<ScannerProvider>();
    final rotation = _rotation;
    try {
      await controller.startImageStream((CameraImage image) {
        scanner.onFrame(
          DetectorFrame(
            width: image.width,
            height: image.height,
            raw: image,
            rotation: rotation,
          ),
        );
        _analyze(image, scanner);
      });
      _streaming = true;
    } catch (e) {
      debugPrint('Could not start the image stream: $e');
    }
  }

  /// Measures light and shaking a few times per second.
  void _analyze(CameraImage image, ScannerProvider scanner) {
    final now = DateTime.now();
    if (now.difference(_lastAnalysis) < AppConstants.analysisInterval) return;
    _lastAnalysis = now;
    if (image.planes.isEmpty) return;

    final plane = image.planes.first; // the brightness plane on Android
    scanner.updateSignals(
      _analyzer.analyze(
        bytes: plane.bytes,
        width: image.width,
        height: image.height,
        rowStride: plane.bytesPerRow,
        pixelStride: plane.bytesPerPixel ?? 1,
      ),
    );
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
    } catch (_) {
      // No flash on this device (all emulators), or the camera refused.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Flash is not available on this device.')),
      );
    }
  }

  // ---------------------------------------------------------------
  // Capture -> result sheet -> save, rescan or discard
  // ---------------------------------------------------------------

  Future<void> _capture() async {
    final controller = _controller;
    final scanner = context.read<ScannerProvider>();
    final settings = context.read<SettingsProvider>();
    if (_capturing ||
        controller == null ||
        !scanner.isLive ||
        scanner.isFrozen) {
      return;
    }
    _capturing = true;

    String? tempPath;
    try {
      // 1. Freeze the count FIRST, so the sheet shows exactly what gets saved.
      final frozen = scanner.freeze();
      FeedbackService.instance.captured(haptic: settings.hapticEnabled);

      // 2. Take the photo and pause the picture.
      tempPath = await _takePhoto(controller);
      if (!mounted) {
        await _imageStore.delete(tempPath);
        return;
      }

      // 3. Ask what to do. The user may correct items first.
      final outcome = await ScanResultSheet.show(context, frozen);
      if (!mounted) {
        await _imageStore.delete(tempPath);
        return;
      }

      switch (outcome.action) {
        case ResultAction.save:
          await _save(outcome.detections, tempPath); // the corrected list
          if (mounted) await _resumeLive();
        case ResultAction.rescan:
          await _imageStore.delete(tempPath);
          if (mounted) await _resumeLive();
        case ResultAction.discard:
          await _imageStore.delete(tempPath);
          if (mounted) Navigator.pop(context); // leave the scanner
      }
    } finally {
      _capturing = false;
    }
  }

  /// Returns the temporary photo's path, or null if the photo failed
  /// (the count is still kept in that case).
  Future<String?> _takePhoto(CameraController controller) async {
    try {
      // Some phones cannot stream frames and take a photo at the same time.
      if (_streaming) {
        await controller.stopImageStream();
        _streaming = false;
      }
      final photo = await controller.takePicture();
      await controller.pausePreview(); // the picture "freezes"
      return photo.path;
    } catch (e) {
      debugPrint('Taking the photo failed: $e');
      return null;
    }
  }

  /// Saves the scan. If the phone is full, the user can free some space and
  /// try again without losing the count.
  Future<void> _save(List<Detection> detections, String? tempPath) async {
    // Read everything we need from the context BEFORE the first await.
    final saver = ScanSaver(add: context.read<HistoryProvider>().add);
    final userId = context.read<AuthProvider>().userId;
    final settings = context.read<SettingsProvider>();
    final messenger = ScaffoldMessenger.of(context);

    final pending = await saver.prepare(tempPath);

    while (true) {
      final outcome = await saver.commit(
        pending,
        detections: detections,
        userId: userId,
      );

      switch (outcome) {
        case SaveOutcome.saved:
        case SaveOutcome.savedWithoutPhoto:
          FeedbackService.instance.saved(
            haptic: settings.hapticEnabled,
            audio: settings.audioEnabled,
          );
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                outcome == SaveOutcome.saved
                    ? 'Saved to history.'
                    : 'Saved to history (without a photo).',
              ),
            ),
          );
          return;

        case SaveOutcome.storageFull:
          if (!mounted) {
            await saver.abandon(pending);
            return;
          }
          final tryAgain = await ConfirmDialog.show(
            context,
            icon: Icons.sd_storage_outlined,
            title: 'Storage space is full',
            message:
                'PesoScan could not save this scan because your phone is '
                'almost full. Free up some space, then tap Try again. You can '
                'also clear scan photos in Settings.',
            confirmLabel: 'Try again',
            cancelLabel: 'Discard scan',
          );
          if (!tryAgain) {
            await saver.abandon(pending);
            return;
          }
        // otherwise: go round the loop and try to save again

        case SaveOutcome.failed:
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Could not save the scan. Please try again.'),
            ),
          );
          await saver.abandon(pending);
          return;
      }
    }
  }

  Future<void> _resumeLive() async {
    final controller = _controller;
    final scanner = context.read<ScannerProvider>();
    try {
      await controller?.resumePreview();
      // Pausing the picture can switch the torch off: put it back if it was on.
      if (_torchOn && controller != null) {
        await controller.setFlashMode(FlashMode.torch);
      }
    } catch (_) {}
    _analyzer.reset();
    scanner.resume();
    if (controller != null) await _startStream(controller);
  }

  // ---------------------------------------------------------------
  // Screen
  // ---------------------------------------------------------------

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

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Light status-bar icons on the dark camera screen.
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: const Color(0xFF030B1C),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Column(
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildPreview(),
                  const GridOverlay(),
                  // The dashed "put your coins here" frame, until items appear.
                  Consumer<ScannerProvider>(
                    builder: (context, scanner, _) => PlacementGuide(
                      visible:
                          hasCamera &&
                          scanner.count == 0 &&
                          !scanner.hasProblem,
                    ),
                  ),
                  // Only the overlays rebuild ~10x per second, not the camera.
                  Consumer<ScannerProvider>(
                    builder: (context, scanner, _) => DetectionOverlay(
                      detections: scanner.detections,
                      frameAspect: _frameAspect,
                    ),
                  ),
                  CornerBrackets(
                    topInset: MediaQuery.paddingOf(context).top + 8,
                  ),
                  ScanLine(animation: _scanLine),

                  // Bottom of the camera area: a hint, or a problem card.
                  Consumer<ScannerProvider>(
                    builder: (context, scanner, _) {
                      Widget? card;
                      if (scanner.hasStartupError) {
                        card = ScanProblemCard(
                          icon: Icons.memory_rounded,
                          title: 'Detection is not available',
                          message: scanner.startupError!,
                          retryLabel: 'Try again',
                          onRetry: scanner.retry,
                        );
                      } else if (scanner.processingFailed) {
                        card = ScanProblemCard(
                          icon: Icons.image_not_supported_outlined,
                          title: 'Unable to process the picture',
                          message:
                              'Something went wrong while reading the '
                              'camera picture. Try again, or restart the app '
                              'if it keeps happening.',
                          retryLabel: 'Try again',
                          onRetry: scanner.retry,
                        );
                      } else if (hasCamera && scanner.noItemsFound) {
                        card = EmptyScanCard(
                          onHelp: () => ScanGuideSheet.show(context),
                        );
                      } else if (hasCamera && scanner.count == 0) {
                        card = const HintChip(
                          text: 'Place coins or bills in frame',
                        );
                      }
                      return Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                          child: card ?? const SizedBox.shrink(),
                        ),
                      );
                    },
                  ),

                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: SafeArea(
                      bottom: false,
                      child: Consumer<ScannerProvider>(
                        builder: (context, scanner, _) => Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ScannerTopBar(
                              onBack: () => Navigator.pop(context),
                              live: scanner.isLive,
                              count: scanner.count,
                            ),
                            if (scanner.isDemoMode) ...[
                              const SizedBox(height: 8),
                              DemoBadge(reason: scanner.demoReason ?? ''),
                            ],
                            const SizedBox(height: 8),
                            ScanStatusStrip(
                              signals: scanner.signals,
                              tips: scanner.tips,
                              onHelp: () => ScanGuideSheet.show(context),
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: GuidanceBanner(
                                tips: scanner.tips,
                                torchOn: _torchOn,
                                onTurnOnFlash: _toggleTorch,
                              ),
                            ),
                          ],
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
              builder: (context, scanner, _) {
                final canCapture = scanner.isLive && !scanner.isFrozen;
                return ScannerControlBar(
                  torchOn: _torchOn,
                  onTorch: _toggleTorch,
                  captureEnabled: canCapture,
                  onCapture: canCapture ? _capture : null,
                  onReset: scanner.reset,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
