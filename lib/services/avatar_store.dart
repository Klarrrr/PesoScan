import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keeps each account's profile picture on THIS phone (it is never uploaded).
class AvatarStore {
  final Future<Directory> Function() _root;

  AvatarStore({Future<Directory> Function()? root})
    : _root = root ?? getApplicationDocumentsDirectory;

  static int _counter = 0;

  static String _key(String userId) => 'avatar_path_$userId';

  /// The saved picture of [userId], or null if there is none.
  Future<String?> load(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_key(userId));
    if (path == null) return null;
    if (!await File(path).exists()) {
      await prefs.remove(_key(userId)); // the file is gone: forget it
      return null;
    }
    return path;
  }

  /// Copies the chosen picture into the app's own folder and remembers it.
  /// The old picture of this account is deleted.
  Future<String> save({
    required String userId,
    required String sourcePath,
  }) async {
    final folder = Directory(p.join((await _root()).path, 'avatars'));
    if (!await folder.exists()) await folder.create(recursive: true);

    // A NEW file name every time, so Flutter does not keep showing the old
    // picture from its memory.
    final name =
        '${userId}_${DateTime.now().millisecondsSinceEpoch}_${_counter++}.jpg';
    final target = p.join(folder.path, name);
    await File(sourcePath).copy(target);

    final prefs = await SharedPreferences.getInstance();
    final old = prefs.getString(_key(userId));
    await prefs.setString(_key(userId), target);
    if (old != null && old != target) await _delete(old);
    return target;
  }

  Future<void> remove(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final old = prefs.getString(_key(userId));
    await prefs.remove(_key(userId));
    if (old != null) await _delete(old);
  }

  Future<void> _delete(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Nothing useful to do if deleting fails.
    }
  }
}
