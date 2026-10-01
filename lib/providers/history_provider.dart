import 'package:flutter/foundation.dart';

import '../models/scan_record.dart';
import '../services/scan_repository.dart';

/// Gives the screens the saved scans. Home uses `recent` and `count`;
/// Part 13 adds the full list, search and delete.
class HistoryProvider extends ChangeNotifier {
  final ScanRepository _repository;
  HistoryProvider(this._repository);

  List<ScanRecord> _recent = const [];
  int _count = 0;

  List<ScanRecord> get recent => _recent;
  int get count => _count;

  Future<void> load() async {
    _recent = await _repository.recent(limit: 3);
    _count = await _repository.count();
    notifyListeners();
  }

  Future<void> add(ScanRecord record) async {
    await _repository.save(record);
    await load();
  }
}
