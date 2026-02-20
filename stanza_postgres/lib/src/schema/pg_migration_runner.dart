import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:stanza/stanza.dart';

/// Status of a single migration file.
class MigrationStatus {
  /// The migration filename (e.g. `'20260219_143022.sql'`).
  final String filename;

  /// Whether this migration has been applied to the database.
  final bool applied;

  /// When the migration was applied (null if pending).
  final DateTime? appliedAt;

  const MigrationStatus({
    required this.filename,
    required this.applied,
    this.appliedAt,
  });
}

/// Applies migration files and tracks them in the database.
///
/// Migration state is tracked in the `_stanza_migrations` table, which
/// is created automatically. Checksums prevent tampering with applied migrations.
class PgMigrationRunner {
  final DatabaseAdapter _db;
  final String _migrationsDir;

  PgMigrationRunner(this._db, {required String migrationsDir})
      : _migrationsDir = migrationsDir;

  /// Creates the `_stanza_migrations` tracking table if it doesn't exist.
  Future<void> ensureTrackingTable() async {
    await _db.rawExecute('''
      CREATE TABLE IF NOT EXISTS _stanza_migrations (
        id SERIAL PRIMARY KEY,
        filename TEXT NOT NULL UNIQUE,
        applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        checksum TEXT NOT NULL
      )
    ''');
  }

  /// Returns the status of all migration files.
  Future<List<MigrationStatus>> status() async {
    await ensureTrackingTable();

    final files = _listMigrationFiles();
    if (files.isEmpty) return [];

    final result = await _db.rawExecute(
      'SELECT filename, applied_at FROM _stanza_migrations '
      'ORDER BY filename',
    );

    final applied = <String, DateTime>{};
    for (final row in result.rows) {
      applied[row['filename'] as String] = row['applied_at'] as DateTime;
    }

    return files.map((f) {
      final name = f.uri.pathSegments.last;
      return MigrationStatus(
        filename: name,
        applied: applied.containsKey(name),
        appliedAt: applied[name],
      );
    }).toList();
  }

  /// Applies all pending migrations in order.
  ///
  /// If [dryRun] is true, prints SQL to stdout without executing.
  /// Returns the list of applied migration filenames.
  Future<List<String>> apply({bool dryRun = false}) async {
    await ensureTrackingTable();

    final files = _listMigrationFiles();
    if (files.isEmpty) return [];

    // Fetch already-applied migrations with checksums
    final result = await _db.rawExecute(
      'SELECT filename, checksum FROM _stanza_migrations ORDER BY filename',
    );
    final appliedChecksums = <String, String>{};
    for (final row in result.rows) {
      appliedChecksums[row['filename'] as String] = row['checksum'] as String;
    }

    // Verify checksums of applied migrations
    for (final file in files) {
      final name = file.uri.pathSegments.last;
      final existingChecksum = appliedChecksums[name];
      if (existingChecksum != null) {
        final content = file.readAsStringSync();
        final actualChecksum = _checksum(content);
        if (actualChecksum != existingChecksum) {
          throw StanzaException(
            'Checksum mismatch for applied migration $name. '
            'The file has been modified after it was applied.',
          );
        }
      }
    }

    // Find and apply pending migrations
    final applied = <String>[];
    for (final file in files) {
      final name = file.uri.pathSegments.last;
      if (appliedChecksums.containsKey(name)) continue;

      final content = file.readAsStringSync();
      final statements = _extractStatements(content);

      if (dryRun) {
        // ignore: avoid_print
        print('-- Migration: $name');
        for (final stmt in statements) {
          // ignore: avoid_print
          print('$stmt;');
        }
        // ignore: avoid_print
        print('');
      } else {
        await _db.transaction((tx) async {
          for (final stmt in statements) {
            await tx.rawExecute(stmt);
          }
          await tx.rawExecute(
            'INSERT INTO _stanza_migrations (filename, checksum) '
            'VALUES (@filename, @checksum)',
            parameters: {
              'filename': name,
              'checksum': _checksum(content),
            },
          );
        });
      }

      applied.add(name);
    }

    return applied;
  }

  /// Lists `.sql` files in the migrations directory, sorted by name.
  List<File> _listMigrationFiles() {
    final dir = Directory(_migrationsDir);
    if (!dir.existsSync()) return [];

    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.sql'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    return files;
  }

  /// Extracts executable SQL statements from a migration file.
  ///
  /// Strips comments, removes BEGIN/COMMIT (runner manages its own transaction),
  /// and splits on `;`.
  static List<String> _extractStatements(String content) {
    final lines = content.split('\n');
    final buf = StringBuffer();

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('--')) continue;
      if (trimmed.isEmpty) continue;
      if (trimmed.toUpperCase() == 'BEGIN;') continue;
      if (trimmed.toUpperCase() == 'COMMIT;') continue;
      buf.write('$trimmed ');
    }

    return buf
        .toString()
        .split(';')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  /// Computes SHA-256 checksum of migration file content.
  static String _checksum(String content) =>
      sha256.convert(utf8.encode(content)).toString();
}
