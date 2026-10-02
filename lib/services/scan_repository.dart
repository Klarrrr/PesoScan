import '../models/scan_record.dart';

/// Where scans are stored. The screens only know THIS interface.
abstract class ScanRepository {
  /// Every scan of the current user, newest first.
  Future<List<ScanRecord>> all();

  Future<void> save(ScanRecord record);

  Future<void> delete(String id);

  /// Deletes every scan of the current user.
  Future<void> clear();
}

/// Temporary storage that lives only while the app is running
/// (used in tests and as a fallback).
class InMemoryScanRepository implements ScanRepository {
  final List<ScanRecord> _items;

  InMemoryScanRepository({List<ScanRecord> seed = const []})
    : _items = [...seed];

  @override
  Future<List<ScanRecord>> all() async =>
      [..._items]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Future<void> save(ScanRecord record) async {
    _items.removeWhere((r) => r.id == record.id);
    _items.add(record);
  }

  @override
  Future<void> delete(String id) async => _items.removeWhere((r) => r.id == id);

  @override
  Future<void> clear() async => _items.clear();
}
