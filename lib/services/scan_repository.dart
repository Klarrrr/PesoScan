import '../models/scan_record.dart';

/// Where scans are stored. The screens only know THIS interface.
/// Part 13 adds a SQLite version; nothing else has to change.
abstract class ScanRepository {
  Future<List<ScanRecord>> recent({int limit = 3});
  Future<int> count();
  Future<void> save(ScanRecord record);
}

/// Temporary storage that lives only while the app is running.
class InMemoryScanRepository implements ScanRepository {
  final List<ScanRecord> _items;

  InMemoryScanRepository({List<ScanRecord> seed = const []})
    : _items = [...seed];

  @override
  Future<List<ScanRecord>> recent({int limit = 3}) async {
    final newestFirst = [..._items]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return newestFirst.take(limit).toList();
  }

  @override
  Future<int> count() async => _items.length;

  @override
  Future<void> save(ScanRecord record) async => _items.add(record);
}
