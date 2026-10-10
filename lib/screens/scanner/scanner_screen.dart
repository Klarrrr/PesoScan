// ignore_for_file: unused_import, unused_shown_name

import 'dart:io' show Platform, File, Directory;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';
import 'package:image_picker/image_picker.dart';

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

  // State to hold the gallery image bytes so it displays on screen
  Uint8List? _galleryBytes;

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
      await _yolo.loadModel();
      _modelReady = true;
      _yoloController.setShowOverlays(false);

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
    try {
      await _yoloController.setTorchMode(!_torchOn);
      if (mounted) setState(() => _torchOn = !_torchOn);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Flash is not available on this device.')),
      );
    }
  }

  Future<void> _pickGalleryImage() async {
    if (!_modelReady) return;

    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null || !mounted) return;

    final scanner = context.read<ScannerProvider>();
    final settings = context.read<SettingsProvider>();

    try {
      final bytes = await file.readAsBytes();

      // Update state to render the gallery photo as the background
      setState(() {
        _galleryBytes = bytes;
      });

      await _yoloController.pause();

      final result = await _yolo.predict(bytes);

      final raw = (result as Map)['detections'] as List?;
      final yoloResults =
          raw?.whereType<Map>().map(YOLOResult.fromMap).toList() ?? [];

      final mappedDetections = yoloResults.map((yolo) {
        final box = yolo.normalizedBox;
        final moneyType = yolo.className.startsWith('bill')
            ? MoneyType.bill
            : MoneyType.coin;
        return Detection(
          money: MoneyClass(
            id: _getMoneyId(yolo.className), // Uses the new mapping function
            valueCentavos: _parseCentavos(yolo.className),
            type: moneyType,
            design: yolo.className,
          ),
          confidence: yolo.confidence,
          box: Rect.fromLTRB(box.left, box.top, box.right, box.bottom),
        );
      }).toList();

      scanner.injectAndFreeze(mappedDetections);
      FeedbackService.instance.captured(haptic: settings.hapticEnabled);

      if (!mounted) return;
      final outcome = await ScanResultSheet.show(context, scanner.detections);

      if (!mounted) return;
      switch (outcome.action) {
        case ResultAction.save:
          await _save(outcome.detections, file.path);
          if (mounted) await _resumeLive();
        case ResultAction.rescan:
        case ResultAction.discard:
          if (mounted) await _resumeLive();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gallery scan failed: $e')));
        await _resumeLive();
      }
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

      final bytes = await _yoloController.captureFrame();
      await _yoloController.pause();

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

    if (!mounted) return;

    // Clear the gallery image to reveal the camera feed again
    setState(() {
      _galleryBytes = null;
    });

    context.read<ScannerProvider>().resume();
  }

  void _handleYoloResults(List<YOLOResult> yoloResults) {
    if (!mounted || !_modelReady) return;

    final detections = yoloResults.map((yolo) {
      final box = yolo.normalizedBox;
      final moneyType = yolo.className.startsWith('bill')
          ? MoneyType.bill
          : MoneyType.coin;

      return Detection(
        money: MoneyClass(
          id: _getMoneyId(yolo.className), // Uses the new mapping function
          valueCentavos: _parseCentavos(yolo.className),
          type: moneyType,
          design: yolo.className,
        ),
        confidence: yolo.confidence,
        box: Rect.fromLTRB(box.left, box.top, box.right, box.bottom),
      );
    }).toList();

    context.read<ScannerProvider>().updateDetections(detections);
  }

  // --- MAPPING FUNCTIONS ---

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

  int _getMoneyId(String className) {
    // Maps the 11 YOLO strings to the 19 specific MoneyClass IDs in money_class.dart
    switch (className) {
      case 'coin_005':
        return 1; // ₱0.05 NGC
      case 'coin_025':
        return 2; // ₱0.25 NGC
      case 'coin_1':
        return 4; // ₱1 NGC (Defaulting to NGC over BSP)
      case 'coin_5':
        return 7; // ₱5 NGC Nonagonal
      case 'coin_10':
        return 9; // ₱10 NGC (Mabini only)
      case '20':
        return 10; // ₱20 NGC Coin
      case 'bill_50':
        return 11; // ₱50 NGC Series
      case 'bill_100':
        return 12; // ₱100 NGC Series
      case 'bill_200':
        return 13; // ₱200 NGC Series
      case 'bill_500':
        return 14; // ₱500 NGC Series
      case 'bill_1000':
        return 19; // ₱1000 Polymer (Defaulting to newest)
      default:
        return 1; // Fallback to prevent crashes
    }
  }
  // --- UI BUILDING ---

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

    // If an image was uploaded from the gallery, show it instead of the camera
    if (_galleryBytes != null) {
      return LayoutBuilder(
        builder: (context, constraints) {
          if (!constraints.biggest.isEmpty) {
            context.read<ScannerProvider>().visibleRegion = FrameMapper(
              area: constraints.biggest,
              frameAspect: 9 / 16,
            ).visibleFrameRect;
          }
          return Image.memory(_galleryBytes!, fit: BoxFit.cover);
        },
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
                        card = Stack(
                          clipBehavior: Clip.none,
                          children: [
                            EmptyScanCard(
                              onHelp: () => ScanGuideSheet.show(context),
                            ),
                            Positioned(
                              top: -8,
                              right: -8,
                              child: GestureDetector(
                                onTap: scanner.dismissEmptyMessage,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.black87,
                                    shape: BoxShape.circle,
                                  ),
                                  padding: const EdgeInsets.all(4),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                          ],
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

                  Positioned(
                    top: MediaQuery.paddingOf(context).top + 8,
                    right: 16,
                    child: IconButton(
                      icon: const Icon(
                        Icons.add_photo_alternate_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                      onPressed: _pickGalleryImage,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black45,
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
