import 'dart:io';

import 'package:crypto/crypto.dart';

import '../stanza.dart';

/// Status of a single migration file.
class MigrationStatus {
  final String filename;
  final bool applied;
  final DateTime? appliedAt;

  const MigrationStatus({
    required this.filename,
    required this.applied,
    this.appliedAt,
  });

  @override
  String toString() =>
      'MigrationStatus($filename, applied=$applied${appliedAt != null ? ', at=$appliedAt' : ''})';
}

/// Applies and tracks migration files against the database.
///
/// Migrations are tracked in a `_stanza_migrations` table. Each file is
/// applied in filename order (which is chronological due to the timestamp
/// prefix). Applied migrations have their SHA-256 checksum recorded to
/// detect tampering.
class MigrationRunner {
  final Stanza _stanza;
  final String migrationsDir;

  const MigrationRunner(this._stanza, {required this.migrationsDir});

  /// Ensures the `_stanza_migrations` tracking table exists.
  Future<void> ensureTrackingTable() async {
    await _stanza.rawExecute('''
CREATE TABLE IF NOT EXISTS _stanza_migrations (
  id SERIAL PRIMARY KEY,
  filename TEXT NOT NULL UNIQUE,
  applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  checksum TEXT NOT NULL
)
''');
  }

  /// Returns the status of all migration files (applied or pending).
  Future<List<MigrationStatus>> status() async {
    await ensureTrackingTable();

    final files = _listMigrationFiles();
    if (files.isEmpty) return [];

    final applied = await _getAppliedMigrations();

    return files.map((file) {
      final name = _filename(file);
      final record = applied[name];
      return MigrationStatus(
        filename: name,
        applied: record != null,
        appliedAt: record?['applied_at'] as DateTime?,
      );
    }).toList();
  }

  /// Applies all pending migration files in order.
  ///
  /// If [dryRun] is true, prints the SQL that would be executed without
  /// actually running it. Returns the list of applied (or would-be-applied)
  /// filenames.
  Future<List<String>> apply({bool dryRun = false}) async {
    await ensureTrackingTable();

    final files = _listMigrationFiles();
    if (files.isEmpty) return [];

    final applied = await _getAppliedMigrations();
    final pending = <File>[];

    // Verify checksums of already-applied files
    for (final file in files) {
      final name = _filename(file);
      final record = applied[name];
      if (record != null) {
        final currentChecksum = _checksum(file);
        if (record['checksum'] != currentChecksum) {
          throw StateError(
            'Checksum mismatch for applied migration "$name". '
            'Applied migrations must not be modified. '
            'Expected: ${record['checksum']}, got: $currentChecksum',
          );
        }
      } else {
        pending.add(file);
      }
    }

    if (pending.isEmpty) return [];

    final appliedNames = <String>[];

    for (final file in pending) {
      final name = _filename(file);
      final content = file.readAsStringSync();
      final checksum = _checksum(file);
      final statements = _extractStatements(content);

      if (dryRun) {
        // ignore: avoid_print
        print('-- Would apply: $name');
        for (final stmt in statements) {
          // ignore: avoid_print
          print(stmt);
        }
      } else {
        // Apply each statement within a transaction
        await _stanza.rawExecute('BEGIN');
        try {
          for (final stmt in statements) {
            await _stanza.rawExecute(stmt);
          }

          // Record in tracking table
          await _stanza.rawExecute(
            'INSERT INTO _stanza_migrations (filename, checksum) '
            'VALUES (@filename, @checksum)',
            parameters: {'filename': name, 'checksum': checksum},
          );

          await _stanza.rawExecute('COMMIT');
        } catch (e) {
          await _stanza.rawExecute('ROLLBACK');
          rethrow;
        }
      }

      appliedNames.add(name);
    }

    return appliedNames;
  }

  List<File> _listMigrationFiles() {
    final dir = Directory(migrationsDir);
    if (!dir.existsSync()) return [];

    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.sql'))
        .toList();

    // Sort by filename (chronological due to timestamp prefix)
    files.sort((a, b) => _filename(a).compareTo(_filename(b)));
    return files;
  }

  Future<Map<String, Map<String, dynamic>>> _getAppliedMigrations() async {
    final rows = await _stanza.rawExecute(
      'SELECT filename, applied_at, checksum FROM _stanza_migrations '
      'ORDER BY filename',
    );

    final result = <String, Map<String, dynamic>>{};
    for (final row in rows) {
      final map = row.toColumnMap();
      result[map['filename'] as String] = map;
    }
    return result;
  }

  /// Extracts executable SQL statements from migration file content.
  ///
  /// Strips comments, BEGIN/COMMIT wrappers, and empty lines.
  List<String> _extractStatements(String content) {
    final statements = <String>[];
    final buf = StringBuffer();

    for (var line in content.split('\n')) {
      line = line.trim();

      // Skip comments and empty lines
      if (line.startsWith('--') || line.isEmpty) continue;

      // Skip BEGIN/COMMIT — runner wraps in its own transaction
      if (line.toUpperCase() == 'BEGIN;' || line.toUpperCase() == 'COMMIT;') {
        continue;
      }

      buf.write('$line ');

      if (line.endsWith(';')) {
        final stmt = buf.toString().trim();
        if (stmt.isNotEmpty && stmt != ';') {
          statements.add(stmt);
        }
        buf.clear();
      }
    }

    // Handle trailing statement without semicolon
    final remaining = buf.toString().trim();
    if (remaining.isNotEmpty) {
      statements.add(remaining);
    }

    return statements;
  }

  String _filename(File file) => file.uri.pathSegments.last;

  String _checksum(File file) {
    final bytes = file.readAsBytesSync();
    return sha256.convert(bytes).toString();
  }
}
