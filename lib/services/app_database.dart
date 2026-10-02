import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Opens (and on first run creates) the app's SQLite database.
class AppDatabase {
  static const _version = 1;

  final Database db;
  AppDatabase._(this.db);

  /// [path] and [factory] can be replaced in tests (in-memory database).
  static Future<AppDatabase> open({
    String? path,
    DatabaseFactory? factory,
  }) async {
    final dbFactory = factory ?? databaseFactory;
    final dbPath =
        path ?? p.join(await dbFactory.getDatabasesPath(), 'pesoscan.db');

    final db = await dbFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(version: _version, onCreate: _onCreate),
    );
    return AppDatabase._(db);
  }

  // Runs ONCE, when the database file does not exist yet. A future change
  // to the tables means raising _version and adding an onUpgrade step.
  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE scans (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        created_at INTEGER NOT NULL,
        image_path TEXT NOT NULL,
        total_centavos INTEGER NOT NULL,
        item_count INTEGER NOT NULL,
        detections_json TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_scans_user_date ON scans (user_id, created_at DESC)',
    );
  }

  Future<void> close() => db.close();
}
