// ignore_for_file: unused_shown_name, unused_import

import 'dart:io' show Platform, File, Directory;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';

import '../../core/app_colors.dart';
import '../../core/app_theme.dart';
import '../../core/constants.dart';
import '../../models/detection.dart';
import '../../models/money_class.dart';
import '../../providers/auth_provider.dart';
import '../../providers/history_provider.dart';
import '../../providers/scanner_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/feedback_service.dart';
import '../../services/permission_service.dart';
import '../../services/scan_image_store.dart';
import '../../services/scan_saver.dart';
import '../../widgets/confirm_dialog.dart';
import 'detection_overlay.dart';
import 'guidance_widgets.dart';
import 'problem_widgets.dart';
import 'scan_result_sheet.dart';
import 'scanner_widgets.dart';
import '../../core/frame_mapper.dart';

class ScannerScreen extends StatelessWidget {
  const ScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ScannerProvider()..start(),
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

  // Ultralytics YOLO Controllers
  final _yoloController = YOLOViewController();
  final _yolo = YOLO(
    modelPath: 'assets/models/pesoscanV1.tflite',
    task: YOLOTask.obb,
  );

  String? _cameraError;
  bool _permissionProblem = false;
  bool _torchOn = false;
  bool _initializing = false;
  bool _capturing = false;
  bool _modelReady = false;

  late final AnimationController _scanLine;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scanLine = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);

    context.read<ScannerProvider>().onItemsLocked = (_) {
      if (!mounted) return;
      final settings = context.read<SettingsProvider>();
      FeedbackService.instance.itemLocked(
        haptic: settings.hapticEnabled,
        audio: settings.audioEnabled,
      );
    };

    _initScanner();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scanLine.dispose();
    _yoloController.dispose();
    _yolo.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _yoloController.pause();
    } else if (state == AppLifecycleState.resumed) {
      _yoloController.resume();
    }
  }

  Future<void> _initScanner() async {
    if (_initializing) return;
    _initializing = true;

    try {
      // 1. Load the YOLO model natively
      await _yolo.loadModel();
      _modelReady = true;
      _yoloController.setShowOverlays(
        false,
      ); // Hide generic overlays, use custom ones

      if (mounted) {
        setState(() {
          _cameraError = null;
          _permissionProblem = false;
        });
      }
    } catch (e) {
      _fail('Could not load pesoscanV1.tflite model: $e');
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

  Future<void> _toggleTorch() async {
    // YOLOViewController lacks a direct torch toggle in this version.
    // We update UI state, but may require a native camera patch for the flash.
    if (mounted) {
      setState(() => _torchOn = !_torchOn);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Flash toggle may require native camera access.'),
        ),
      );
    }
  }

  Future<void> _capture() async {
    final scanner = context.read<ScannerProvider>();
    final settings = context.read<SettingsProvider>();
    if (_capturing || !_modelReady || !scanner.isLive || scanner.isFrozen) {
      return;
    }

    _capturing = true;
    String? tempPath;

    try {
      final frozen = scanner.freeze();
      FeedbackService.instance.captured(haptic: settings.hapticEnabled);

      // Capture frame via YOLO controller
      final bytes = await _yoloController.captureFrame();
      await _yoloController.pause();

      // Write captured bytes to a temporary image file so the save sheet can use it
      if (bytes != null) {
        final tempFile = File(
          '${Directory.systemTemp.path}/pesoscan_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        await tempFile.writeAsBytes(bytes);
        tempPath = tempFile.path;
      }

      if (!mounted) return;
      final outcome = await ScanResultSheet.show(context, frozen);

      if (!mounted) return;
      switch (outcome.action) {
        case ResultAction.save:
          await _save(outcome.detections, tempPath);
          if (mounted) await _resumeLive();
        case ResultAction.rescan:
          if (tempPath != null) await _imageStore.delete(tempPath);
          if (mounted) await _resumeLive();
        case ResultAction.discard:
          if (tempPath != null) await _imageStore.delete(tempPath);
          if (mounted) Navigator.pop(context);
      }
    } finally {
      _capturing = false;
    }
  }

  Future<void> _save(List<Detection> detections, String? tempPath) async {
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
            message: 'Free up some space, then tap Try again.',
            confirmLabel: 'Try again',
            cancelLabel: 'Discard scan',
          );
          if (!tryAgain) {
            await saver.abandon(pending);
            return;
          }
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
    try {
      await _yoloController.resume();
    } catch (_) {}

    // Add this guard to ensure the widget still exists before using 'context'
    if (!mounted) return;

    context.read<ScannerProvider>().resume();
  }

  // Maps Ultralytics YOLOResult to your app's Detection class
  void _handleYoloResults(List<YOLOResult> yoloResults) {
    if (!mounted || !_modelReady) return;

    final detections = yoloResults.map((yolo) {
      final box = yolo.normalizedBox;
      // You must ensure your MoneyClass logic matches the yolo.className
      final moneyType = yolo.className.startsWith('bill')
          ? MoneyType.bill
          : MoneyType.coin;

      return Detection(
        money: MoneyClass(
          id: yolo.classIndex,
          valueCentavos: _parseCentavos(yolo.className),
          type: moneyType,
          design: yolo.className,
        ),
        confidence: yolo.confidence,
        box: Rect.fromLTRB(box.left, box.top, box.right, box.bottom),
      );
    }).toList();

    // Feed the translated detections directly into your provider
    context.read<ScannerProvider>().updateDetections(detections);
  }

  int _parseCentavos(String className) {
    const values = <String, int>{
      'bill_100': 10000,
      'bill_1000': 100000,
      'bill_200': 20000,
      'bill_50': 5000,
      'bill_500': 50000,
      'coin_005': 5,
      'coin_025': 25,
      'coin_1': 100,
      'coin_10': 1000,
      'coin_5': 500,
      '20': 2000,
    };
    return values[className] ?? 0;
  }

  Widget _buildPreview() {
    if (_cameraError != null) {
      return CameraErrorView(
        message: _cameraError!,
        permissionProblem: _permissionProblem,
        onRetry: _initScanner,
        onOpenSettings: PermissionService.openSettings,
      );
    }

    if (!_modelReady) {
      return Center(
        child: CircularProgressIndicator(color: context.colors.gold),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.biggest.isEmpty) {
          context.read<ScannerProvider>().visibleRegion = FrameMapper(
            area: constraints.biggest,
            frameAspect: 9 / 16,
          ).visibleFrameRect;
        }

        return YOLOView(
          modelPath: 'assets/models/pesoscanV1.tflite',
          task: YOLOTask.obb,
          controller: _yoloController,
          onResult: _handleYoloResults,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
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

                  Consumer<ScannerProvider>(
                    builder: (context, scanner, _) => DetectionOverlay(
                      detections: scanner.detections,
                      frameAspect: 9 / 16,
                    ),
                  ),
                  CornerBrackets(
                    topInset: MediaQuery.paddingOf(context).top + 8,
                  ),
                  ScanLine(animation: _scanLine),

                  Consumer<ScannerProvider>(
                    builder: (context, scanner, _) {
                      Widget? card;
                      if (scanner.noItemsFound && _modelReady) {
                        card = EmptyScanCard(
                          onHelp: () => ScanGuideSheet.show(context),
                        );
                      } else if (scanner.count == 0 && _modelReady) {
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
