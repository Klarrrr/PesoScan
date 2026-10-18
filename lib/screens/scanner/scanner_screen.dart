// ignore_for_file: unused_shown_name, unused_import

import 'dart:io' show Platform, File, Directory;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../core/app_colors.dart';
import '../../core/app_theme.dart';
import '../../core/constants.dart';
import '../../core/money.dart';
import '../../models/detection.dart';
import '../../models/money_class.dart';
import '../../models/scan_record.dart';
import '../../providers/auth_provider.dart';
import '../../providers/history_provider.dart';
import '../../providers/scanner_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/feedback_service.dart';
import '../../services/permission_service.dart';
import 'detection_overlay.dart';
import 'guidance_widgets.dart';
import 'problem_widgets.dart';
import 'scanner_widgets.dart';
import '../../core/frame_mapper.dart';
import 'scan_result_sheet.dart'; // We will update this file next!

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
  final _yoloController = YOLOViewController();
  final _yolo = YOLO(
    modelPath: 'assets/models/pesoscanV1.tflite',
    task: YOLOTask.obb,
  );
  final FlutterTts _tts = FlutterTts();

  String? _cameraError;
  bool _permissionProblem = false;
  bool _torchOn = false;
  bool _initializing = false;
  bool _capturing = false;
  bool _modelReady = false;

  Uint8List? _galleryBytes;
  late final AnimationController _scanLine;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tts.setLanguage("en-PH");
    _tts.setSpeechRate(0.5);

    _scanLine = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);

    context.read<ScannerProvider>().onItemsLocked = (_) {
      if (!mounted) {
        return;
      }
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
    _tts.stop();
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
    if (_initializing) {
      return;
    }
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
    if (!mounted) {
      return;
    }
    setState(() {
      _cameraError = message;
      _permissionProblem = permission;
    });
  }

  Future<void> _toggleTorch() async {
    try {
      await _yoloController.setTorchMode(!_torchOn);
      if (mounted) {
        setState(() => _torchOn = !_torchOn);
      }
    } catch (e) {
      // Print the error to the console instead of leaving the catch block empty
      debugPrint('Torch error: $e');
    }
  }

  Future<void> _speakTotal(int centavos) async {
    final settings = context.read<SettingsProvider>();
    if (!settings.audioEnabled || centavos == 0) {
      return;
    }
    final pesos = centavos ~/ 100;
    final cents = centavos % 100;
    String text = "The total counted value is ";
    if (pesos > 0) {
      text += "$pesos peso${pesos == 1 ? '' : 's'}";
    }
    if (pesos > 0 && cents > 0) {
      text += " and ";
    }
    if (cents > 0) {
      text += "$cents centavo${cents == 1 ? '' : 's'}";
    }
    await _tts.speak(text);
  }

  Future<void> _pickGalleryImage() async {
    if (!_modelReady) {
      return;
    }
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null || !mounted) {
      return;
    }

    final scanner = context.read<ScannerProvider>();
    final settings = context.read<SettingsProvider>();

    try {
      final bytes = await file.readAsBytes();
      setState(() => _galleryBytes = bytes);
      await _yoloController.pause();

      final result = await _yolo.predict(bytes);
      final raw = (result as Map)['detections'] as List?;
      final yoloResults =
          raw?.whereType<Map>().map(YOLOResult.fromMap).toList() ?? [];

      final mappedDetections = yoloResults
          .where((yolo) => yolo.className != 'bill_200')
          .map((yolo) {
            final box = yolo.normalizedBox;
            final moneyType = yolo.className.startsWith('bill')
                ? MoneyType.bill
                : MoneyType.coin;
            return Detection(
              money: MoneyClass(
                id: _getMoneyId(yolo.className),
                valueCentavos: _parseCentavos(yolo.className),
                type: moneyType,
                design: yolo.className,
              ),
              confidence: yolo.confidence,
              box: Rect.fromLTRB(box.left, box.top, box.right, box.bottom),
            );
          })
          .toList();

      scanner.injectAndFreeze(mappedDetections);
      FeedbackService.instance.captured(haptic: settings.hapticEnabled);
      _speakTotal(scanner.totalCentavos);

      if (!mounted) {
        return;
      }

      // Pass the file.path into the sheet
      final outcome = await ScanResultSheet.show(
        context,
        scanner.detections,
        file.path,
      );
      await _handleSheetOutcome(outcome, file.path, scanner);
    } catch (e) {
      if (mounted) {
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
      final bytes = await _yoloController.captureFrame();
      await _yoloController.pause();
      List<Detection> finalDetections = scanner.freeze();

      if (bytes != null) {
        final tempFile = File(
          '${Directory.systemTemp.path}/pesoscan_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        await tempFile.writeAsBytes(bytes);
        tempPath = tempFile.path;

        try {
          final result = await _yolo.predict(bytes);
          final raw = (result as Map)['detections'] as List?;
          final yoloResults =
              raw?.whereType<Map>().map(YOLOResult.fromMap).toList() ?? [];

          finalDetections = yoloResults
              .where((yolo) => yolo.className != 'bill_200')
              .map((yolo) {
                final box = yolo.normalizedBox;
                final moneyType = yolo.className.startsWith('bill')
                    ? MoneyType.bill
                    : MoneyType.coin;
                return Detection(
                  money: MoneyClass(
                    id: _getMoneyId(yolo.className),
                    valueCentavos: _parseCentavos(yolo.className),
                    type: moneyType,
                    design: yolo.className,
                  ),
                  confidence: yolo.confidence,
                  box: Rect.fromLTRB(box.left, box.top, box.right, box.bottom),
                );
              })
              .toList();

          scanner.injectAndFreeze(finalDetections);
        } catch (e) {
          debugPrint('Double check prediction failed: $e');
        }
      }

      FeedbackService.instance.captured(haptic: settings.hapticEnabled);
      _speakTotal(scanner.totalCentavos);

      if (!mounted) {
        return;
      }

      // Pass the tempPath into the sheet
      final outcome = await ScanResultSheet.show(
        context,
        finalDetections,
        tempPath,
      );
      await _handleSheetOutcome(outcome, tempPath, scanner);
    } finally {
      _capturing = false;
    }
  }

  Future<void> _handleSheetOutcome(
    SheetOutcome outcome,
    String? tempPath,
    ScannerProvider scanner,
  ) async {
    if (!mounted) {
      return;
    }

    if (outcome.action == ResultAction.saveSession) {
      await _saveSessionToHistory(scanner);
    } else if (outcome.action == ResultAction.discard) {
      if (tempPath != null && !outcome.wasAdded) {
        try {
          await File(tempPath).delete();
        } catch (e) {
          debugPrint('Delete error: $e');
        }
      }

      scanner.resetRunningTotal();

      // --- FIX: Check if the screen is still active after deleting the file ---
      if (!mounted) {
        return;
      }
      Navigator.pop(context);
    } else {
      if (tempPath != null && !outcome.wasAdded) {
        try {
          await File(tempPath).delete();
        } catch (e) {
          debugPrint('Delete error: $e');
        }
      }
      await _resumeLive();
    }
  }

  Future<void> _saveSessionToHistory(ScannerProvider scanner) async {
    final history = context.read<HistoryProvider>();
    final auth = context.read<AuthProvider>();
    final settings = context.read<SettingsProvider>();

    if (scanner.sessionFrames.isEmpty) {
      await _resumeLive();
      return;
    }

    final record = ScanRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      createdAt: DateTime.now(),
      userId: auth.userId,
      frames: List.from(scanner.sessionFrames),
    );

    await history.add(record);
    FeedbackService.instance.saved(
      haptic: settings.hapticEnabled,
      audio: settings.audioEnabled,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session saved to history.')),
      );
    }

    scanner.resetRunningTotal();
    await _resumeLive();
  }

  Future<void> _resumeLive() async {
    try {
      await _yoloController.resume();
    } catch (_) {}
    if (!mounted) {
      return;
    }
    setState(() => _galleryBytes = null);
    context.read<ScannerProvider>().resume();
  }

  void _handleYoloResults(List<YOLOResult> yoloResults) {
    if (!mounted || !_modelReady) {
      return;
    }

    final detections = yoloResults
        .where((yolo) => yolo.className != 'bill_200')
        .map((yolo) {
          final box = yolo.normalizedBox;
          final moneyType = yolo.className.startsWith('bill')
              ? MoneyType.bill
              : MoneyType.coin;
          return Detection(
            money: MoneyClass(
              id: _getMoneyId(yolo.className),
              valueCentavos: _parseCentavos(yolo.className),
              type: moneyType,
              design: yolo.className,
            ),
            confidence: yolo.confidence,
            box: Rect.fromLTRB(box.left, box.top, box.right, box.bottom),
          );
        })
        .toList();

    context.read<ScannerProvider>().updateDetections(detections);
  }

  int _parseCentavos(String className) {
    const values = <String, int>{
      'bill_100': 10000,
      'bill_1000': 100000,
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
    switch (className) {
      case 'coin_005':
        return 1;
      case 'coin_025':
        return 2;
      case 'coin_1':
        return 4;
      case 'coin_5':
        return 7;
      case 'coin_10':
        return 9;
      case '20':
        return 10;
      case 'bill_50':
        return 16;
      case 'bill_100':
        return 17;
      case 'bill_500':
        return 18;
      case 'bill_1000':
        return 19;
      default:
        return 1;
    }
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

            // --- RESTORED: Your original bottom layout ---
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
