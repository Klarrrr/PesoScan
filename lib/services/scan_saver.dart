import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/detection.dart';
import '../models/scan_record.dart';
import 'scan_image_store.dart';
import 'storage_errors.dart';

enum SaveOutcome { saved, savedWithoutPhoto, storageFull, failed }

/// A scan whose photo is already stored but which is not yet in the database.
class PendingScan {
  final String id;
  final String imagePath; // '' = no photo
  final bool photoLost; // the photo was expected but could not be kept

  const PendingScan({
    required this.id,
    required this.imagePath,
    required this.photoLost,
  });
}

/// Saves a scan in two steps, so a "storage full" problem can be retried
/// without losing the user's count:
///   1. prepare()  moves the camera's temporary photo into permanent storage
///   2. commit()   writes the scan to the database (can be repeated)
class ScanSaver {
  final Future<void> Function(ScanRecord record) _add;
  final ScanImageStore _images;
  final String Function() _newId;
  final DateTime Function() _now;

  ScanSaver({
    required this._add,
    ScanImageStore? images,
    String Function()? newId,
    DateTime Function()? now,
  }) : _images = images ?? ScanImageStore(),
       _newId = newId ?? (() => const Uuid().v4()),
       _now = now ?? DateTime.now;

  Future<PendingScan> prepare(String? tempPhotoPath) async {
    final id = _newId();
    if (tempPhotoPath == null) {
      return PendingScan(id: id, imagePath: '', photoLost: true);
    }
    try {
      final path = await _images.save(tempPath: tempPhotoPath, scanId: id);
      return PendingScan(id: id, imagePath: path, photoLost: false);
    } catch (e) {
      // For example the phone is full: keep the count, drop the photo.
      debugPrint('Saving the photo failed: $e');
      await _images.delete(tempPhotoPath);
      return PendingScan(id: id, imagePath: '', photoLost: true);
    }
  }

  Future<SaveOutcome> commit(
    PendingScan pending, {
    required List<Detection> detections,
    required String? userId,
  }) async {
    try {
      await _add(
        ScanRecord(
          id: pending.id,
          createdAt: _now(),
          imagePath: pending.imagePath,
          detections: detections,
          userId: userId,
        ),
      );
      return pending.photoLost
          ? SaveOutcome.savedWithoutPhoto
          : SaveOutcome.saved;
    } catch (e) {
      debugPrint('Saving the scan failed: $e');
      return isStorageFullError(e)
          ? SaveOutcome.storageFull
          : SaveOutcome.failed;
    }
  }

  /// The scan will not be saved after all: remove its photo.
  Future<void> abandon(PendingScan pending) =>
      _images.delete(pending.imagePath);
}
