import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Keeps scan photos in the app's own storage folder.
/// The camera first writes a TEMPORARY file; we move it here only if
/// the user presses Save.
class ScanImageStore {
  final Future<Directory> Function() _root;

  /// `root` can be replaced in tests with a temporary folder.
  ScanImageStore({Future<Directory> Function()? root})
    : _root = root ?? getApplicationDocumentsDirectory;

  Future<Directory> _scansFolder() async {
    final folder = Directory(p.join((await _root()).path, 'scans'));
    if (!await folder.exists()) await folder.create(recursive: true);
    return folder;
  }

  /// Total size in bytes of those files that exist.
  Future<int> totalSize(Iterable<String> paths) async {
    var total = 0;
    for (final path in paths) {
      if (path.isEmpty) continue;
      try {
        final file = File(path);
        if (await file.exists()) total += await file.length();
      } catch (_) {
        // A file we cannot read counts as zero.
      }
    }
    return total;
  }

  /// Copies the camera's temporary photo into permanent storage
  /// and deletes the temporary file. Returns the new path.
  Future<String> save({
    required String tempPath,
    required String scanId,
  }) async {
    final folder = await _scansFolder();
    final target = p.join(folder.path, '$scanId.jpg');
    await File(tempPath).copy(target);
    await delete(tempPath);
    return target;
  }

  /// Deletes a file if it exists. Safe to call with null or a missing file.
  Future<void> delete(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Nothing useful to do if deleting fails.
    }
  }
}
