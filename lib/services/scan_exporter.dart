import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:gal/gal.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/money.dart';
import '../models/scan_record.dart';

/// A problem we can explain to the user in one sentence.
class ExportException implements Exception {
  final String message;
  const ExportException(this.message);

  @override
  String toString() => message;
}

/// What happened. [message] is shown in a snackbar (empty = show nothing).
class ExportOutcome {
  final bool ok;
  final String message;
  const ExportOutcome(this.ok, this.message);
}

/// Turns the widget behind [boundaryKey] into PNG bytes.
typedef CaptureFn = Future<Uint8List> Function(GlobalKey boundaryKey);

/// "Takes a screenshot" of one RepaintBoundary. [pixelRatio] 3 = sharp.
Future<Uint8List> captureBoundaryPng(
  GlobalKey boundaryKey, {
  double pixelRatio = 3,
}) async {
  final boundary = boundaryKey.currentContext?.findRenderObject();
  if (boundary is! RenderRepaintBoundary) {
    throw const ExportException('The picture is not ready yet. Try again.');
  }
  // In debug mode Flutter may not have painted the very latest frame yet.
  if (kDebugMode && boundary.debugNeedsPaint) {
    await Future<void>.delayed(const Duration(milliseconds: 40));
  }

  final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) {
      throw const ExportException('The picture could not be created.');
    }
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  } finally {
    image.dispose();
  }
}

/// The three things that touch the phone. Behind an interface so tests
/// can use a fake instead of the real plugins.
abstract class ExportActions {
  Future<void> shareImage({
    required Uint8List png,
    required String fileName,
    required String text,
  });

  Future<void> saveToGallery({
    required Uint8List png,
    required String fileName,
  });

  Future<void> copyText(String text);
}

class PlatformExportActions implements ExportActions {
  Future<File> _writeTemp(Uint8List png, String fileName) async {
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, fileName));
    await file.writeAsBytes(png, flush: true);
    return file;
  }

  @override
  Future<void> shareImage({
    required Uint8List png,
    required String fileName,
    required String text,
  }) async {
    final file = await _writeTemp(png, fileName);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'image/png')],
        text: text,
        subject: 'PesoScan result',
      ),
    );
  }

  @override
  Future<void> saveToGallery({
    required Uint8List png,
    required String fileName,
  }) async {
    final file = await _writeTemp(png, fileName);
    try {
      // Android 10+ needs no permission; older phones ask once.
      if (!await Gal.hasAccess(toAlbum: true)) {
        final granted = await Gal.requestAccess(toAlbum: true);
        if (!granted) {
          throw const ExportException(
            'Allow photo access in Settings to save pictures.',
          );
        }
      }
      await Gal.putImage(file.path, album: 'PesoScan');
    } on GalException catch (e) {
      throw ExportException(_galMessage(e.type.name));
    } finally {
      try {
        await file.delete(); // the gallery has its own copy now
      } catch (_) {}
    }
  }

  String _galMessage(String kind) {
    switch (kind) {
      case 'accessDenied':
        return 'Allow photo access in Settings to save pictures.';
      case 'notEnoughSpace':
        return 'Your phone is almost full. Free up some space and try again.';
      default:
        return 'The picture could not be saved.';
    }
  }

  @override
  Future<void> copyText(String text) =>
      Clipboard.setData(ClipboardData(text: text));
}

/// Share / save / copy for one scan.
class ScanExporter {
  final CaptureFn _capture;
  final ExportActions _actions;

  ScanExporter({CaptureFn? capture, ExportActions? actions})
    : _capture = capture ?? captureBoundaryPng,
      _actions = actions ?? PlatformExportActions();

  /// pesoscan_20260930_101800.png
  String fileNameFor(ScanRecord record) =>
      'pesoscan_${DateFormat('yyyyMMdd_HHmmss').format(record.createdAt)}.png';

  /// Opens the Android share sheet with the picture.
  Future<ExportOutcome> share(GlobalKey card, ScanRecord record) {
    return _run(() async {
      final png = await _capture(card);
      await _actions.shareImage(
        png: png,
        fileName: fileNameFor(record),
        text: 'Counted with PesoScan: ${formatPeso(record.totalCentavos)}',
      );
    });
  }

  /// Puts the picture in the gallery.
  Future<ExportOutcome> saveToDevice(GlobalKey card, ScanRecord record) {
    return _run(() async {
      final png = await _capture(card);
      await _actions.saveToGallery(png: png, fileName: fileNameFor(record));
    }, successMessage: 'Saved to your gallery (PesoScan album).');
  }

  /// Copies "₱32.25".
  Future<ExportOutcome> copyTotal(ScanRecord record) {
    final total = formatPeso(record.totalCentavos);
    return _run(
      () => _actions.copyText(total),
      successMessage: 'Total $total copied.',
    );
  }

  Future<ExportOutcome> _run(
    Future<void> Function() work, {
    String successMessage = '',
  }) async {
    try {
      await work();
      return ExportOutcome(true, successMessage);
    } on ExportException catch (e) {
      return ExportOutcome(false, e.message);
    } catch (e) {
      debugPrint('Export failed: $e');
      return const ExportOutcome(
        false,
        'Something went wrong. Please try again.',
      );
    }
  }
}
