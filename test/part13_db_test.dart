@Tags(['db'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:pesoscan/services/app_database.dart';
import 'package:pesoscan/services/sample_data.dart';
import 'package:pesoscan/services/sqlite_scan_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit(); // lets SQLite run in tests on your laptop

  late AppDatabase database;

  setUp(() async {
    database = await AppDatabase.open(
      path: inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
  });

  tearDown(() => database.close());

  SqliteScanRepository repoFor(String? user) =>
      SqliteScanRepository(database.db, userId: () => user);

  test('saves scans and reads them back newest first', () async {
    final repo = repoFor('A');
    final samples = devSampleScans(userId: 'A');
    for (final s in samples) {
      await repo.save(s);
    }

    final loaded = await repo.all();
    expect(loaded.length, 8);
    expect(loaded.first.id, samples.first.id); // the newest one
    expect(loaded.first.totalCentavos, samples.first.totalCentavos);
    expect(loaded.first.detections.length, samples.first.detections.length);
    expect(
      loaded.first.detections.first.money.id,
      samples.first.detections.first.money.id,
    );
  });

  test('each user only sees their own scans', () async {
    for (final s in devSampleScans(userId: 'A').take(3)) {
      await repoFor('A').save(s);
    }
    for (final s in devSampleScans(userId: 'B').take(2)) {
      await repoFor('B').save(s);
    }

    expect((await repoFor('A').all()).length, 3);
    expect((await repoFor('B').all()).length, 2);
    expect((await repoFor('C').all()), isEmpty);
  });

  test('delete and clear only touch the current user', () async {
    final a = devSampleScans(userId: 'A').take(3).toList();
    for (final s in a) {
      await repoFor('A').save(s);
    }
    for (final s in devSampleScans(userId: 'B').take(2)) {
      await repoFor('B').save(s);
    }

    await repoFor('A').delete(a.first.id);
    expect((await repoFor('A').all()).length, 2);

    await repoFor('A').clear();
    expect(await repoFor('A').all(), isEmpty);
    expect((await repoFor('B').all()).length, 2); // untouched
  });
}
