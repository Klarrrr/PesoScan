import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;

import '../services/avatar_store.dart';
import '../services/photo_picker.dart';
import 'auth_provider.dart';

enum AvatarChange { changed, cancelled, cameraDenied, failed }

/// The profile picture of whoever is signed in.
class AvatarProvider extends ChangeNotifier {
  final AvatarStore _store;
  final AuthProvider _auth;
  final PhotoPicker _picker;
  String? _lastUserId;
  String? _path;
  bool _disposed = false;

  AvatarProvider(this._store, this._auth, {PhotoPicker? picker})
    : _picker = picker ?? ImagePickerPhotoPicker() {
    _lastUserId = _auth.userId;
    _auth.addListener(_onAuthChanged);
  }

  /// Path of the picture, or null (then the screens show the initial).
  String? get path => _path;
  bool get hasPhoto => _path != null;

  // A different account logged in: show THEIR picture.
  void _onAuthChanged() {
    if (_auth.userId == _lastUserId) return;
    _lastUserId = _auth.userId;
    _path = null;
    _notify();
    load();
  }

  Future<void> load() async {
    final id = _auth.userId;
    String? found;
    if (id != null) {
      try {
        found = await _store.load(id);
      } catch (e) {
        debugPrint('Could not load the profile picture: $e');
      }
    }
    _path = found;
    _notify();
  }

  /// Ask the picker and keep the answer.
  Future<AvatarChange> choose(PhotoSource source) async {
    final userId = _auth.userId;
    if (userId == null) return AvatarChange.failed;
    try {
      final picked = await _picker.pick(source);
      if (picked == null) return AvatarChange.cancelled;
      _path = await _store.save(userId: userId, sourcePath: picked);
      _notify();
      return AvatarChange.changed;
    } on PlatformException catch (e) {
      // The picture picker asks for the camera permission itself.
      if (e.code == 'camera_access_denied') return AvatarChange.cameraDenied;
      debugPrint('Changing the profile picture failed: $e');
      return AvatarChange.failed;
    } catch (e) {
      debugPrint('Changing the profile picture failed: $e');
      return AvatarChange.failed;
    }
  }

  Future<void> remove() async {
    final id = _auth.userId;
    if (id == null) return;
    try {
      await _store.remove(id);
    } catch (e) {
      debugPrint('Removing the profile picture failed: $e');
    }
    _path = null;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _auth.removeListener(_onAuthChanged);
    super.dispose();
  }
}
