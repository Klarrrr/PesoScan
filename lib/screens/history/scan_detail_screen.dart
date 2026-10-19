// ignore_for_file: unused_import

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:gal/gal.dart';

import '../../core/app_colors.dart';
import '../../core/app_theme.dart';
import '../../core/frame_mapper.dart';
import '../../core/money.dart';
import '../../core/scan_math.dart';
import '../../models/detection.dart';
import '../../models/money_class.dart';
import '../../models/scan_record.dart';
import '../../widgets/screen_header.dart';
import '../../services/scan_exporter.dart';
import '../../widgets/auth_scaffold.dart' show BrandLogo;

class ScanDetailScreen extends StatefulWidget {
  final ScanRecord record;
  final ScanExporter? exporter;

  const ScanDetailScreen({super.key, required this.record, this.exporter});

  @override
  State<ScanDetailScreen> createState() => _ScanDetailScreenState();
}

class _ScanDetailScreenState extends State<ScanDetailScreen> {
  final GlobalKey _cardKey = GlobalKey();
  late final ScanExporter _exporter = widget.exporter ?? ScanExporter();
  String? _busy;

  // null = "All", otherwise index of the selected frame
  int? _selectedIndex;

  Future<void> _run(
    String action,
    Future<ExportOutcome> Function() work,
  ) async {
    if (_busy != null) {
      return;
    }

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

    if (!mounted) {
      return;
    }

    if (message.isNotEmpty) {
      messenger.removeCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 1500),
        ),
      );
    }
  }

  void _showFullImage(String path) {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            alignment: Alignment.center,
            children: [
              InteractiveViewer(
                child: Image.file(File(path), fit: BoxFit.contain),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.download_rounded, size: 28),
                  color: Colors.white,
                  style: IconButton.styleFrom(backgroundColor: Colors.black54),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      final hasAccess = await Gal.hasAccess();
                      if (!hasAccess) {
                        await Gal.requestAccess();
                      }
                      await Gal.putImage(path);

                      if (!mounted) {
                        return;
                      }
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Original photo saved to Gallery'),
                        ),
                      );
                    } catch (e) {
                      if (!mounted) {
                        return;
                      }
                      messenger.showSnackBar(
                        SnackBar(content: Text('Failed to save image: $e')),
                      );
                    }
                  },
                ),
              ),
              Positioned(
                top: 8,
                left: 8,
                child: IconButton(
                  icon: const Icon(Icons.close, size: 28),
                  color: Colors.white,
                  style: IconButton.styleFrom(backgroundColor: Colors.black54),
                  onPressed: () => Navigator.pop(dialogContext),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final record = widget.record;

    final allDetections = record.frames.expand((f) => f.detections).toList();
    final uniqueDenominations = allDetections
        .map((d) => d.money.id)
        .toSet()
        .length;

    final displayDetections = _selectedIndex == null
        ? allDetections
        : record.frames[_selectedIndex!].detections;

    final displayTotal = _selectedIndex == null
        ? record.totalCentavos
        : record.frames[_selectedIndex!].frameTotalCentavos;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          children: [
            const Text(
              'History Detail',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              DateFormat('MMM d, yyyy · hh:mm a').format(record.createdAt),
              style: TextStyle(fontSize: 12, color: c.textMuted),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          child: RepaintBoundary(
            key: _cardKey,
            child: Container(
              color: c.background,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. HERO CARD (Full Session Total)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: c.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'FULL SESSION TOTAL',
                              style: TextStyle(
                                color: c.textMuted,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: c.gold.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: c.gold),
                              ),
                              child: Text(
                                '${record.frames.length} IMAGES',
                                style: TextStyle(
                                  color: c.gold,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            formatPeso(record.totalCentavos),
                            style: TextStyle(
                              color: c.gold,
                              fontSize: 44,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _StatText('${record.itemCount}', 'items'),
                            Container(width: 1, height: 16, color: c.border),
                            _StatText('${record.frames.length}', 'images'),
                            Container(width: 1, height: 16, color: c.border),
                            _StatText('$uniqueDenominations', 'denominations'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 2. SCANNED IMAGES CAROUSEL
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Scanned Images',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Select one for details',
                        style: TextStyle(fontSize: 12, color: c.textMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 100,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        // "All" Selector
                        GestureDetector(
                          onTap: () => setState(() => _selectedIndex = null),
                          child: Container(
                            width: 80,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              color: _selectedIndex == null
                                  ? c.gold.withValues(alpha: 0.1)
                                  : c.surface,
                              border: Border.all(
                                color: _selectedIndex == null
                                    ? c.gold
                                    : c.border,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.bar_chart_rounded,
                                  color: _selectedIndex == null
                                      ? c.gold
                                      : c.textMuted,
                                  size: 28,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'All',
                                  style: TextStyle(
                                    color: _selectedIndex == null
                                        ? c.gold
                                        : c.textMuted,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Individual Image Thumbnails
                        for (var i = 0; i < record.frames.length; i++)
                          GestureDetector(
                            onTap: () => setState(() => _selectedIndex = i),
                            child: Container(
                              width: 100,
                              margin: const EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: _selectedIndex == i
                                      ? c.gold
                                      : c.border,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                image: DecorationImage(
                                  image: FileImage(
                                    File(record.frames[i].imagePath),
                                  ),
                                  fit: BoxFit.cover,
                                ),
                              ),
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.7),
                                    borderRadius: const BorderRadius.vertical(
                                      bottom: Radius.circular(14),
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 6,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'IMG ${i + 1}',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        formatPesoShort(
                                          record.frames[i].frameTotalCentavos,
                                        ),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: c.gold,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 3. VIEW & SAVE PHOTO BUTTON (When an image is selected)
                  if (_selectedIndex != null) ...[
                    OutlinedButton.icon(
                      onPressed: () => _showFullImage(
                        record.frames[_selectedIndex!].imagePath,
                      ),
                      icon: Icon(
                        Icons.fullscreen,
                        color: c.textPrimary,
                        size: 18,
                      ),
                      label: Text(
                        'View & Save Original Photo',
                        style: TextStyle(color: c.textPrimary),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: c.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // 4. DENOMINATION BREAKDOWN TABLE
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _selectedIndex == null
                            ? 'General Denomination Total'
                            : 'Image Breakdown',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      if (_selectedIndex != null) ...[
                        Text(
                          formatPeso(displayTotal),
                          style: TextStyle(
                            color: c.gold,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  _ItemsTable(detections: displayDetections),

                  // 5. SEPARATE ITEM CONFIDENCE TABLE (Always shown for All & Per Image)
                  const SizedBox(height: 16),
                  _ConfidenceTable(detections: displayDetections),

                  // 6. EXPORT BUTTONS
                  const SizedBox(height: 32),
                  Row(
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --- HELPER COMPONENTS ---

class _StatText extends StatelessWidget {
  final String value;
  final String label;
  const _StatText(this.value, this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 16,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(color: context.colors.textMuted, fontSize: 12),
        ),
      ],
    );
  }
}

/// Denomination Breakdown Table (Clean, without confidence tags)
class _ItemsTable extends StatelessWidget {
  final List<Detection> detections;
  const _ItemsTable({required this.detections});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final groups = countByClass(detections).entries.toList();

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
                Expanded(child: Text('ITEM / SERIES', style: text.labelSmall)),
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

/// Separate Item Confidence Table matching your reference image
class _ConfidenceTable extends StatelessWidget {
  final List<Detection> detections;
  const _ConfidenceTable({required this.detections});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;

    // Sort items by denomination value (highest to lowest), then by confidence
    final sorted = List<Detection>.from(detections)
      ..sort((a, b) {
        final byVal = b.money.valueCentavos.compareTo(a.money.valueCentavos);
        if (byVal != 0) {
          return byVal;
        }
        return b.confidence.compareTo(a.confidence);
      });

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: c.background,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text('ITEM CONFIDENCE', style: text.labelSmall),
          ),
          for (final (i, d) in sorted.indexed)
            Container(
              color: i.isEven ? c.surface : c.background,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: d.money.shortValue,
                            style: TextStyle(
                              fontFamily: AppFonts.heading,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: c.textPrimary,
                            ),
                          ),
                          TextSpan(
                            text: ' ${d.money.design}',
                            style: TextStyle(fontSize: 14, color: c.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Text(
                    '${(d.confidence * 100).toStringAsFixed(1)}%',
                    style: AppText.mono(
                      size: 15,
                      color: d.confidence >= 0.90
                          ? c.success
                          : (d.confidence >= 0.75 ? c.warning : c.danger),
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
