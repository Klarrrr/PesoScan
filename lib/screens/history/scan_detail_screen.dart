// ignore_for_file: unused_import

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

import '../../services/scan_exporter.dart';
import '../../widgets/auth_scaffold.dart' show BrandLogo;

/// Page 11 of the prototype.
/// Page 11 of the prototype, plus Share / Save / Copy (Part 16).

/// Page 11 of the prototype, plus Share / Save / Copy (Part 16).
class ScanDetailScreen extends StatefulWidget {
  final ScanRecord record;

  /// Tests pass an exporter with fake actions; the app uses the real one.
  final ScanExporter? exporter;

  const ScanDetailScreen({super.key, required this.record, this.exporter});

  @override
  State<ScanDetailScreen> createState() => _ScanDetailScreenState();
}

class _ScanDetailScreenState extends State<ScanDetailScreen> {
  // Marks the part of the screen that becomes the exported picture.
  final GlobalKey _cardKey = GlobalKey();
  late final ScanExporter _exporter = widget.exporter ?? ScanExporter();

  /// 'share' | 'save' | 'copy' while one is running, otherwise null.
  String? _busy;

  Future<void> _run(
    String action,
    Future<ExportOutcome> Function() work,
  ) async {
    if (_busy != null) return; // ignore taps while one is running
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = action);

    String message = '';
    try {
      final outcome = await work();
      message = outcome.message;
    } catch (e) {
      if (e is ExportException) {
        message = e.message;
      } else {
        message = 'Something went wrong. Please try again.';
      }
    } finally {
      if (mounted) {
        setState(() => _busy = null);
      }
    }

    if (!mounted) return;

    if (message.isNotEmpty) {
      messenger.removeCurrentSnackBar(); // clears existing snackbar immediately
      messenger.showSnackBar(
        SnackBar(
          content: Text(message),
          behavior:
              SnackBarBehavior.floating, // floats cleanly so gestures pass
          duration: const Duration(milliseconds: 1500),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final record = widget.record;

    return Scaffold(
      body: SafeArea(
        // A plain scroll view (not ListView) builds everything at once, so
        // the whole card exists and can be photographed.
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ScreenHeader(
                  title: 'Scan Detail',
                  subtitle: DateFormat('EEEE, MMMM d, yyyy')
                      .format(record.createdAt),
                ),
              ),
              const SizedBox(height: 14),

              // Everything inside this RepaintBoundary is what gets exported.
              RepaintBoundary(
                key: _cardKey,
                child: Container(
                  color: c.background, // solid, so the PNG is not see-through
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _BrandRow(when: record.createdAt),
                      const SizedBox(height: 14),
                      _ScanPhoto(record: record),
                      const SizedBox(height: 14),
                      _SummaryCard(record: record),
                      const SizedBox(height: 14),
                      _ItemsTable(record: record),
                      const SizedBox(height: 14),
                      Text(
                        'Counted with PesoScan. For counting only: it cannot '
                        'tell real money from fake.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: _ExportButton(
                        key: const Key('btn-share'),
                        icon: Icons.ios_share_rounded,
                        label: 'Share',
                        busy: _busy == 'share',
                        enabled: _busy == null,
                        onTap: () => _run(
                          'share',
                          () => _exporter.share(_cardKey, record),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ExportButton(
                        key: const Key('btn-save'),
                        icon: Icons.download_rounded,
                        label: 'Save',
                        busy: _busy == 'save',
                        enabled: _busy == null,
                        onTap: () => _run(
                          'save',
                          () => _exporter.saveToDevice(_cardKey, record),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ExportButton(
                        key: const Key('btn-copy'),
                        icon: Icons.copy_rounded,
                        label: 'Copy total',
                        busy: _busy == 'copy',
                        enabled: _busy == null,
                        onTap: () =>
                            _run('copy', () => _exporter.copyTotal(record)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Logo, name and date at the top of the exported picture.
class _BrandRow extends StatelessWidget {
  final DateTime when;
  const _BrandRow({required this.when});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Row(
      children: [
        const BrandLogo(size: 28),
        const SizedBox(width: 8),
        Text.rich(
          TextSpan(
            style: const TextStyle(
              fontFamily: AppFonts.heading,
              fontWeight: FontWeight.w700,
              fontSize: 20,
            ),
            children: [
              TextSpan(
                text: 'Peso',
                style: TextStyle(color: c.textPrimary),
              ),
              TextSpan(
                text: 'Scan',
                style: TextStyle(color: c.gold),
              ),
            ],
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            DateFormat('MMM d, yyyy · hh:mm a').format(when),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: AppText.mono(
              size: 11,
              weight: FontWeight.w400,
              color: c.textMuted,
            ),
          ),
        ),
      ],
    );
  }
}

class _ExportButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool busy;
  final bool enabled;
  final VoidCallback onTap;

  const _ExportButton({
    super.key,
    required this.icon,
    required this.label,
    required this.busy,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Opacity(
      opacity: (enabled || busy) ? 1 : 0.5,
      child: Material(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: enabled && !busy ? onTap : null,
          child: Container(
            height: 68,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.border),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                busy
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: c.gold,
                        ),
                      )
                    : Icon(icon, color: c.gold, size: 24),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: c.textSecondary,
                  ),
                ),
              ],
            ),
          ),
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
