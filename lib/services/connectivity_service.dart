import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MissingPluginException;

/// Tells the app whether the phone has a network connection.
/// (It says "a network exists", not "the internet works".)
class ConnectivityService {
  ConnectivityService._() : _online = true, _started = false;

  /// A service you control by hand (for tests).
  @visibleForTesting
  ConnectivityService.forTesting({this._online = true}) : _started = true;

  static final ConnectivityService instance = ConnectivityService._();

  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  bool _online;
  bool _started;

  bool get isOnline => _online;

  /// Emits true/false whenever the connection changes.
  Stream<bool> get changes => _controller.stream;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    try {
      final dynamic first = await Connectivity().checkConnectivity();
      _apply(first);
      Connectivity().onConnectivityChanged.listen(
        _apply,
        onError: (Object _) {},
      );
    } catch (e) {
      // No plugin (for example in tests): assume we are online.
      if (e is! MissingPluginException) {
        debugPrint('Connectivity is not available: $e');
      }
    }
  }

  // Newer versions of the plugin report a LIST of connections, older ones a
  // single value. This accepts both.
  void _apply(dynamic result) {
    final list = result is List ? result : [result];
    setOnline(list.any((r) => r != ConnectivityResult.none));
  }

  @visibleForTesting
  void setOnline(bool value) {
    if (value == _online) return;
    _online = value;
    _controller.add(value);
  }
}
