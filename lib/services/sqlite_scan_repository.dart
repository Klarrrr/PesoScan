import 'package:sqflite/sqflite.dart';

import '../models/scan_record.dart';
import 'scan_repository.dart';

/// Stores scans in SQLite, separately for each user.
class SqliteScanRepository implements ScanRepository {
  final Database _db;
  final String? Function() _currentUserId;

  /// [userId] is asked every time, so switching accounts just works.
  SqliteScanRepository(this._db, {required String? Function() userId})
    : _currentUserId = userId;

  /// "Only this user's rows" as an SQL condition.
  (String, List<Object?>) _userScope() {
    final id = _currentUserId();
    return id == null
        ? ('user_id IS NULL', <Object?>[])
        : ('user_id = ?', <Object?>[id]);
  }

  @override
  Future<List<ScanRecord>> all() async {
    final (where, args) = _userScope();
    final rows = await _db.query(
      'scans',
      where: where,
      whereArgs: args,
      orderBy: 'created_at DESC',
    );
    return rows.map(ScanRecord.fromMap).toList();
  }

  @override
  Future<void> save(ScanRecord record) async {
    await _db.insert(
      'scans',
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> delete(String id) async {
    final (where, args) = _userScope();
    await _db.delete(
      'scans',
      where: 'id = ? AND $where',
      whereArgs: [id, ...args],
    );
  }

  @override
  Future<void> clear() async {
    final (where, args) = _userScope();
    await _db.delete('scans', where: where, whereArgs: args);
  }
}
