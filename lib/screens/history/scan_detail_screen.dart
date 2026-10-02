import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/app_colors.dart';
import '../../core/app_theme.dart';
import '../../core/frame_mapper.dart';
import '../../core/money.dart';
import '../../core/scan_math.dart';
import '../../models/detection.dart';
import '../../models/scan_record.dart';
import '../../widgets/screen_header.dart';

/// Page 11 of the prototype.
class ScanDetailScreen extends StatelessWidget {
  final ScanRecord record;
  const ScanDetailScreen({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            ScreenHeader(
              title: 'Scan Detail',
              subtitle: DateFormat('EEEE, MMMM d, yyyy')
                  .format(record.createdAt),
            ),
            const SizedBox(height: 18),
            _ScanPhoto(record: record),
            const SizedBox(height: 16),
            _SummaryCard(record: record),
            const SizedBox(height: 16),
            _ItemsTable(record: record),
          ],
        ),
      ),
    );
  }
}

/// The saved photo with a box on every item.
class _ScanPhoto extends StatefulWidget {
  final ScanRecord record;
  const _ScanPhoto({required this.record});

  @override
  State<_ScanPhoto> createState() => _ScanPhotoState();
}

class _ScanPhotoState extends State<_ScanPhoto> {
  File? _file;
  double? _aspect; // photo width / height, known once the photo is read
  ImageStream? _stream;
  ImageStreamListener? _listener;

  @override
  void initState() {
    super.initState();
    final path = widget.record.imagePath;
    if (path.isNotEmpty) {
      final file = File(path);
      if (file.existsSync()) {
        _file = file;
        _readPhotoSize(file);
      }
    }
  }

  // Ask Flutter for the photo's real shape, so the boxes line up with it.
  void _readPhotoSize(File file) {
    final stream = FileImage(file).resolve(const ImageConfiguration());
    final listener = ImageStreamListener(
      (info, _) {
        if (mounted) {
          setState(() => _aspect = info.image.width / info.image.height);
        }
      },
      onError: (error, stack) {
        if (mounted) setState(() => _file = null);
      },
    );
    stream.addListener(listener);
    _stream = stream;
    _listener = listener;
  }

  @override
  void dispose() {
    final listener = _listener;
    if (listener != null) _stream?.removeListener(listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final aspect = _aspect ?? 3 / 4; // a neutral shape until the photo is read

    return Center(
      child: ConstrainedBox(
        // Tall portrait photos must not fill the whole screen.
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.5,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: AspectRatio(
            aspectRatio: aspect,
            child: LayoutBuilder(
              builder: (context, constraints) {
                // The area has the photo's own shape, so this maps 1:1.
                final mapper = FrameMapper(
                  area: constraints.biggest,
                  frameAspect: aspect,
                );
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_file != null)
                      Image.file(_file!, fit: BoxFit.fill)
                    else
                      const _NoPhoto(),
                    for (final d in widget.record.detections)
                      Positioned.fromRect(
                        rect: mapper.toArea(d.box),
                        child: _LevelBox(detection: d),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _NoPhoto extends StatelessWidget {
  const _NoPhoto();

  @override
  Widget build(BuildContext context) {
    const c = PesoColors.dark;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0B1A12), Color(0xFF050B08)],
        ),
      ),
      alignment: Alignment.bottomCenter,
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.image_not_supported_outlined,
            size: 16,
            color: c.textMuted,
          ),
          const SizedBox(width: 6),
          Text(
            'No photo saved',
            style: TextStyle(color: c.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// Outline coloured by confidence, with the value on its corner.
class _LevelBox extends StatelessWidget {
  final Detection detection;
  const _LevelBox({required this.detection});

  @override
  Widget build(BuildContext context) {
    const c = PesoColors.dark;
    final color = switch (detection.level) {
      ConfidenceLevel.high => c.success,
      ConfidenceLevel.medium => c.warning,
      ConfidenceLevel.low => c.danger,
    };

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color, width: 1.6),
            ),
          ),
        ),
        Positioned(
          left: 4,
          top: -10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              detection.money.shortValue,
              style: AppText.mono(size: 10, color: c.background),
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final ScanRecord record;
  const _SummaryCard({required this.record});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('TOTAL VALUE', style: text.labelSmall),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    formatPeso(record.totalCentavos),
                    style: AppText.mono(size: 32, color: c.gold),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('ITEMS', style: text.labelSmall),
              const SizedBox(height: 4),
              Text(
                '${record.itemCount}',
                style: AppText.mono(size: 32, color: c.textPrimary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ItemsTable extends StatelessWidget {
  final ScanRecord record;
  const _ItemsTable({required this.record});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final groups = countByClass(record.detections).entries.toList();

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: [
          Container(
            color: c.background,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(child: Text('ITEM', style: text.labelSmall)),
                SizedBox(width: 56, child: Text('QTY', style: text.labelSmall)),
                SizedBox(
                  width: 100,
                  child: Text(
                    'VALUE',
                    textAlign: TextAlign.right,
                    style: text.labelSmall,
                  ),
                ),
              ],
            ),
          ),
          for (final (i, e) in groups.indexed)
            Container(
              color: i.isEven ? c.surface : c.background,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.key.shortValue,
                          style: TextStyle(
                            fontFamily: AppFonts.heading,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: c.textPrimary,
                          ),
                        ),
                        Text(
                          '${e.key.design} · ${e.key.typeLabel}',
                          style: text.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 56,
                    child: Text(
                      '×${e.value}',
                      style: AppText.mono(size: 15, color: c.gold),
                    ),
                  ),
                  SizedBox(
                    width: 100,
                    child: Text(
                      formatPeso(e.key.valueCentavos * e.value),
                      textAlign: TextAlign.right,
                      style: AppText.mono(size: 15, color: c.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
