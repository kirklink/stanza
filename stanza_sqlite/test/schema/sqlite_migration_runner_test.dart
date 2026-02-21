import 'dart:io';

import 'package:stanza_sqlite/stanza_sqlite.dart';
import 'package:test/test.dart';

void main() {
  late StanzaSqlite db;
  late SqliteMigrationRunner runner;
  late Directory tempDir;

  setUp(() {
    db = StanzaSqlite.memory();
    tempDir = Directory.systemTemp.createTempSync('stanza_test_');
    runner = SqliteMigrationRunner(db, migrationsDir: tempDir.path);
  });

  tearDown(() async {
    await db.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('SqliteMigrationRunner', () {
    test('creates tracking table', () async {
      await runner.ensureTrackingTable();

      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='_stanza_migrations'",
        mapper: (row) => row['name'] as String,
      );
      expect(tables, ['_stanza_migrations']);
    });

    test('status returns empty for no migrations', () async {
      final status = await runner.status();
      expect(status, isEmpty);
    });

    test('status shows pending migration', () async {
      File('${tempDir.path}/20240101_000000.sql').writeAsStringSync(
        'BEGIN;\nCREATE TABLE foo (id INTEGER PRIMARY KEY);\nCOMMIT;\n',
      );

      final status = await runner.status();
      expect(status, hasLength(1));
      expect(status.first.filename, '20240101_000000.sql');
      expect(status.first.applied, isFalse);
      expect(status.first.appliedAt, isNull);
    });

    test('applies pending migration', () async {
      File('${tempDir.path}/20240101_000000.sql').writeAsStringSync(
        'BEGIN;\nCREATE TABLE foo (id INTEGER PRIMARY KEY, name TEXT);\nCOMMIT;\n',
      );

      final applied = await runner.apply();
      expect(applied, ['20240101_000000.sql']);

      // Verify table was created
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='foo'",
        mapper: (row) => row['name'] as String,
      );
      expect(tables, ['foo']);
    });

    test('status shows applied migration after apply', () async {
      File('${tempDir.path}/20240101_000000.sql').writeAsStringSync(
        'BEGIN;\nCREATE TABLE foo (id INTEGER PRIMARY KEY);\nCOMMIT;\n',
      );

      await runner.apply();

      final status = await runner.status();
      expect(status, hasLength(1));
      expect(status.first.applied, isTrue);
      expect(status.first.appliedAt, isNotNull);
    });

    test('skips already-applied migrations', () async {
      File('${tempDir.path}/20240101_000000.sql').writeAsStringSync(
        'BEGIN;\nCREATE TABLE foo (id INTEGER PRIMARY KEY);\nCOMMIT;\n',
      );

      await runner.apply();

      File('${tempDir.path}/20240102_000000.sql').writeAsStringSync(
        'BEGIN;\nCREATE TABLE bar (id INTEGER PRIMARY KEY);\nCOMMIT;\n',
      );

      final applied = await runner.apply();
      expect(applied, ['20240102_000000.sql']);
    });

    test('applies migrations in filename order', () async {
      File('${tempDir.path}/20240102_000000.sql').writeAsStringSync(
        'BEGIN;\nCREATE TABLE second (id INTEGER PRIMARY KEY);\nCOMMIT;\n',
      );
      File('${tempDir.path}/20240101_000000.sql').writeAsStringSync(
        'BEGIN;\nCREATE TABLE first (id INTEGER PRIMARY KEY);\nCOMMIT;\n',
      );

      final applied = await runner.apply();
      expect(applied, ['20240101_000000.sql', '20240102_000000.sql']);
    });

    test('rejects modified applied migration', () async {
      final file = File('${tempDir.path}/20240101_000000.sql');
      file.writeAsStringSync(
        'BEGIN;\nCREATE TABLE foo (id INTEGER PRIMARY KEY);\nCOMMIT;\n',
      );

      await runner.apply();

      // Modify the file after applying
      file.writeAsStringSync(
        'BEGIN;\nCREATE TABLE foo (id INTEGER PRIMARY KEY, name TEXT);\nCOMMIT;\n',
      );

      expect(
        () => runner.apply(),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Checksum mismatch'),
        )),
      );
    });

    test('dry-run does not execute', () async {
      File('${tempDir.path}/20240101_000000.sql').writeAsStringSync(
        'BEGIN;\nCREATE TABLE foo (id INTEGER PRIMARY KEY);\nCOMMIT;\n',
      );

      final applied = await runner.apply(dryRun: true);
      expect(applied, ['20240101_000000.sql']);

      // Table should NOT exist
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='foo'",
        mapper: (row) => row['name'] as String,
      );
      expect(tables, isEmpty);
    });

    test('handles empty migrations directory', () async {
      final emptyDir = Directory('${tempDir.path}/empty');
      final emptyRunner =
          SqliteMigrationRunner(db, migrationsDir: emptyDir.path);
      final applied = await emptyRunner.apply();
      expect(applied, isEmpty);
    });
  });
}
