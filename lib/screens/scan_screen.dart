import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';

const _modelPath = 'assets/models/pesoscanV1.tflite';

const _values = <String, double>{
  'bill_100': 100,
  'bill_1000': 1000,
  'bill_200': 200,
  'bill_50': 50,
  'bill_500': 500,
  'coin_005': 0.05,
  'coin_025': 0.25,
  'coin_1': 1,
  'coin_10': 10,
  'coin_5': 5,
  '20': 20,
};

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _controller = YOLOViewController();
  final _yolo = YOLO(modelPath: _modelPath, task: YOLOTask.obb);
  final _picker = ImagePicker();
  final _moneyFormat = NumberFormat('#,##0.00');

  List<YOLOResult> _liveResults = const [];
  List<YOLOResult> _stillResults = const [];
  Uint8List? _stillBytes;
  Uint8List? _annotatedBytes;
  int _tab = 0;
  bool _modelReady = false;
  bool _busy = false;

  double get _total => (_tab == 0 ? _liveResults : _stillResults).fold(
    0,
    (sum, result) => sum + (_values[result.className] ?? 0),
  );

  List<YOLOResult> get _results => _tab == 0 ? _liveResults : _stillResults;

  @override
  void initState() {
    super.initState();
    _prepareModel();
    _requestCamera();
    _controller.setShowOverlays(false);
  }

  Future<void> _prepareModel() async {
    try {
      await _yolo.loadModel();
      if (mounted) setState(() => _modelReady = true);
    } catch (error) {
      _showMessage('Could not load pesoscanV1.tflite: $error');
    }
  }

  Future<bool> _requestCamera() async {
    final status = await Permission.camera.request();
    if (!status.isGranted && mounted) {
      await _showPermissionDialog('Camera access is needed for live scanning.');
    }
    return status.isGranted;
  }

  Future<bool> _requestPhotos() async {
    final statuses = await <Permission>[
      Permission.photos,
      Permission.storage,
    ].request();
    final granted = statuses.values.any((status) => status.isGranted);
    if (!granted && mounted) {
      await _showPermissionDialog(
        'Photo access is needed to choose an image and save scans.',
      );
    }
    return granted;
  }

  Future<void> _pickImage() async {
    if (!await _requestPhotos()) return;
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file == null || !_modelReady) return;
    setState(() => _busy = true);
    try {
      final bytes = await file.readAsBytes();
      final result = await _yolo.predict(bytes);
      final detections = _detectionsFrom(result);
      if (!mounted) return;
      setState(() {
        _stillBytes = bytes;
        _annotatedBytes = result['annotatedImage'] as Uint8List?;
        _stillResults = detections;
        _tab = 2;
      });
    } catch (error) {
      _showMessage('Image inference failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _capture() async {
    if (!_modelReady || _busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await _controller.captureFrame();
      if (bytes == null) throw StateError('The camera did not return a frame.');
      final result = await _yolo.predict(bytes);
      if (!mounted) return;
      setState(() {
        _stillBytes = bytes;
        _annotatedBytes = result['annotatedImage'] as Uint8List?;
        _stillResults = _detectionsFrom(result);
        _tab = 1;
      });
      await _controller.pause();
    } catch (error) {
      _showMessage('Capture failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _retake() async {
    await _controller.resume();
    if (mounted) {
      setState(() {
        _tab = 0;
        _stillBytes = null;
        _annotatedBytes = null;
        _stillResults = const [];
      });
    }
  }

  Future<void> _scanAgain() async {
    final bytes = _stillBytes;
    if (bytes == null || _busy) return;
    setState(() => _busy = true);
    try {
      final result = await _yolo.predict(bytes);
      if (mounted) {
        setState(() {
          _annotatedBytes = result['annotatedImage'] as Uint8List?;
          _stillResults = _detectionsFrom(result);
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<YOLOResult> _detectionsFrom(Map<dynamic, dynamic> result) {
    final raw = result['detections'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map(YOLOResult.fromMap)
        .where((item) => _values.containsKey(item.className))
        .toList(growable: false);
  }

  Future<void> _saveToGallery() async {
    final bytes = _annotatedBytes;
    if (bytes == null) {
      _showMessage('Run a scan before saving.');
      return;
    }
    if (!await _requestPhotos()) return;
    try {
      final export = await _addTotalBanner(bytes);
      final name =
          'pesoscan_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}';
      await Gal.putImageBytes(export, name: name, album: 'PesoScan');
      _showMessage('Saved to Gallery');
    } on GalException catch (error) {
      _showMessage('Could not save to Gallery: ${error.type}');
    } catch (error) {
      _showMessage('Could not save to Gallery: $error');
    }
  }

  Future<Uint8List> _addTotalBanner(Uint8List source) async {
    final codec = await ui.instantiateImageCodec(source);
    final image = (await codec.getNextFrame()).image;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImage(image, Offset.zero, Paint());
    final bannerHeight = math.max(72.0, image.width * 0.12).toDouble();
    final banner = Paint()..color = const Color(0xdd0b6e4f);
    canvas.drawRect(
      Rect.fromLTWH(
        0,
        image.height.toDouble() - bannerHeight,
        image.width.toDouble(),
        bannerHeight,
      ),
      banner,
    );
    final paragraph =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(
              fontSize: image.width * 0.045,
              fontWeight: FontWeight.bold,
              textAlign: TextAlign.center,
            ),
          )
          ..pushStyle(ui.TextStyle(color: const Color(0xffffffff)))
          ..addText('Total: ₱${_moneyFormat.format(_total)}');
    final text = paragraph.build()
      ..layout(ui.ParagraphConstraints(width: image.width.toDouble()));
    canvas.drawParagraph(
      text,
      Offset(0, image.height - bannerHeight + (bannerHeight - text.height) / 2),
    );
    return (await recorder.endRecording().toImage(image.width, image.height))
        .toByteData(format: ui.ImageByteFormat.png)
        .then((data) => data!.buffer.asUint8List());
  }

  Future<void> _showPermissionDialog(String message) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permission needed'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open settings'),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _controller.dispose();
    _yolo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PesoScan')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildBody()),
            _TotalBanner(
              total: _total,
              breakdown: _breakdown(_results),
              format: _moneyFormat,
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) {
          if (index == 2) {
            _pickImage();
          } else if (index == 0) {
            _retake();
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.camera_alt_outlined),
            selectedIcon: Icon(Icons.camera_alt),
            label: 'Live',
          ),
          NavigationDestination(
            icon: Icon(Icons.photo_camera_outlined),
            selectedIcon: Icon(Icons.photo_camera),
            label: 'Capture',
          ),
          NavigationDestination(
            icon: Icon(Icons.photo_library_outlined),
            selectedIcon: Icon(Icons.photo_library),
            label: 'Gallery',
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (!_modelReady) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_tab == 0) {
      return Stack(
        fit: StackFit.expand,
        children: [
          YOLOView(
            modelPath: _modelPath,
            task: YOLOTask.obb,
            controller: _controller,
            onResult: (results) => setState(() => _liveResults = results),
          ),
          IgnorePointer(
            child: CustomPaint(painter: _DetectionPainter(_liveResults)),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 20,
            child: FilledButton.icon(
              onPressed: _busy ? null : _capture,
              icon: const Icon(Icons.camera),
              label: const Text('Capture'),
            ),
          ),
        ],
      );
    }
    return Column(
      children: [
        Expanded(
          child: _stillBytes == null
              ? const Center(child: Text('No scan yet'))
              : _FrameWithOverlay(bytes: _stillBytes!, results: _stillResults),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _retake,
                icon: const Icon(Icons.refresh),
                label: const Text('Retake'),
              ),
              OutlinedButton.icon(
                onPressed: _busy ? null : _scanAgain,
                icon: const Icon(Icons.replay),
                label: const Text('Scan Again'),
              ),
              FilledButton.icon(
                onPressed: _saveToGallery,
                icon: const Icon(Icons.save_alt),
                label: const Text('Save to Gallery'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _breakdown(List<YOLOResult> results) {
    final counts = <String, int>{};
    for (final result in results) {
      counts.update(result.className, (value) => value + 1, ifAbsent: () => 1);
    }
    return counts.entries
        .map(
          (entry) =>
              '${entry.value}× ₱${_moneyFormat.format(_values[entry.key])}',
        )
        .join(' · ');
  }
}

class _TotalBanner extends StatelessWidget {
  const _TotalBanner({
    required this.total,
    required this.breakdown,
    required this.format,
  });

  final double total;
  final String breakdown;
  final NumberFormat format;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total: ₱${format.format(total)}',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            breakdown.isEmpty ? 'No denominations detected' : breakdown,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _FrameWithOverlay extends StatelessWidget {
  const _FrameWithOverlay({required this.bytes, required this.results});

  final Uint8List bytes;
  final List<YOLOResult> results;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.memory(bytes, fit: BoxFit.contain),
        IgnorePointer(child: CustomPaint(painter: _DetectionPainter(results))),
      ],
    );
  }
}

class _DetectionPainter extends CustomPainter {
  const _DetectionPainter(this.results);

  final List<YOLOResult> results;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = const Color(0xff00e676)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    for (final result in results) {
      final points = result.obbPointsNormalized;
      final path = Path();
      if (points != null && points.length >= 4) {
        for (var i = 0; i < points.length; i++) {
          final point = points[i];
          final offset = Offset(
            (point['x'] ?? 0).toDouble() * size.width,
            (point['y'] ?? 0).toDouble() * size.height,
          );
          if (i == 0) {
            path.moveTo(offset.dx, offset.dy);
          } else {
            path.lineTo(offset.dx, offset.dy);
          }
        }
        path.close();
      } else {
        final box = result.normalizedBox;
        path.addRect(
          Rect.fromLTRB(
            box.left * size.width,
            box.top * size.height,
            box.right * size.width,
            box.bottom * size.height,
          ),
        );
      }
      canvas.drawPath(path, stroke);
      final box = result.normalizedBox;
      final label =
          '${result.className} ${(result.confidence * 100).toStringAsFixed(0)}%';
      final builder =
          ui.ParagraphBuilder(
              ui.ParagraphStyle(fontSize: 13, fontWeight: FontWeight.bold),
            )
            ..pushStyle(ui.TextStyle(color: const Color(0xffffffff)))
            ..addText(label);
      final paragraph = builder.build()
        ..layout(const ui.ParagraphConstraints(width: 180));
      final labelOffset = Offset(
        box.left * size.width,
        box.top * size.height - 18,
      );
      canvas.drawRect(
        Rect.fromLTWH(
          labelOffset.dx,
          math.max(0, labelOffset.dy),
          paragraph.maxIntrinsicWidth + 8,
          18,
        ),
        Paint()..color = const Color(0xdd00695c),
      );
      canvas.drawParagraph(
        paragraph,
        Offset(labelOffset.dx + 4, math.max(0, labelOffset.dy)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DetectionPainter oldDelegate) =>
      oldDelegate.results != results;
}
