import 'package:flutter/material.dart';

import '../core/date_groups.dart';
import '../core/scan_search.dart';
import '../models/scan_record.dart';
import '../services/scan_image_store.dart';
import '../services/scan_repository.dart';
import 'auth_provider.dart';

/// The saved scans, plus the search text and date filter on top of them.
class HistoryProvider extends ChangeNotifier {
  final ScanRepository _repository;
  final AuthProvider _auth;
  final ScanImageStore _imageStore;
  final DateTime Function() _now;

  HistoryProvider(
    this._repository,
    this._auth, {
    ScanImageStore? imageStore,
    DateTime Function()? now,
  }) : _imageStore = imageStore ?? ScanImageStore(),
       _now = now ?? DateTime.now {
    _lastUserId = _auth.userId;
    _auth.addListener(_onAuthChanged);
  }

  List<ScanRecord> _all = const [];
  String _query = '';
  DateTimeRange? _range;
  String? _lastUserId;

  /// Every scan of this user, newest first.
  List<ScanRecord> get all => _all;
  List<ScanRecord> get recent => _all.take(3).toList();
  int get count => _all.length;

  String get query => _query;
  DateTimeRange? get range => _range;
  bool get hasFilters => _query.trim().isNotEmpty || _range != null;

  List<ScanRecord> get filtered => [
    for (final scan in _all)
      if (_inRange(scan) && scanMatchesQuery(scan, _query, now: _now())) scan,
  ];

  List<HistoryGroup> get groups => groupScans(filtered, _now());

  bool _inRange(ScanRecord scan) {
    final r = _range;
    if (r == null) return true;
    final start = DateTime(r.start.year, r.start.month, r.start.day);
    final endExclusive = DateTime(r.end.year, r.end.month, r.end.day + 1);
    return !scan.createdAt.isBefore(start) &&
        scan.createdAt.isBefore(endExclusive);
  }

  // A different account logged in: show THEIR scans.
  void _onAuthChanged() {
    if (_auth.userId == _lastUserId) return;
    _lastUserId = _auth.userId;
    _query = '';
    _range = null;
    load();
  }

  Future<void> load() async {
    _all = await _repository.all();
    notifyListeners();
  }

  Future<void> add(ScanRecord record) async {
    await _repository.save(record);
    await load();
  }

  Future<void> addAll(List<ScanRecord> records) async {
    for (final record in records) {
      await _repository.save(record);
    }
    await load();
  }

  /// Deletes the scan AND its photo file.
  Future<void> delete(ScanRecord record) async {
    await _repository.delete(record.id);
    await _imageStore.delete(record.imagePath);
    await load();
  }

  Future<void> clearAll() async {
    final old = List.of(_all);
    await _repository.clear();
    for (final record in old) {
      await _imageStore.delete(record.imagePath);
    }
    await load();
  }

  void setQuery(String value) {
    _query = value;
    notifyListeners();
  }

  void setRange(DateTimeRange? value) {
    _range = value;
    notifyListeners();
  }

  void clearFilters() {
    _query = '';
    _range = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    super.dispose();
  }
}
