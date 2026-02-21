import 'dart:io';

import 'package:stanza/stanza.dart';

import '../sqlite_database.dart';
import 'sqlite_schema_manager.dart';

/// CLI helper for SQLite schema management commands.
///
/// Usage in a project's `bin/migrate.dart`:
/// ```dart
/// void main(List<String> args) => SqliteCli.run(
///   args,
///   databasePath: 'app.db',
///   tables: [userTable, postTable],
/// );
/// ```
class SqliteCli {
  /// Runs the CLI with the given arguments.
  ///
  /// Provide either [databasePath] or [db], not both.
  static Future<void> run(
    List<String> args, {
    String? databasePath,
    DatabaseAdapter? db,
    required List<TableDescriptor> tables,
    String migrationsDir = 'migrations',
  }) async {
    assert(
      (databasePath != null) ^ (db != null),
      'Provide either databasePath or db, not both',
    );

    final database = db ?? StanzaSqlite.open(databasePath!);
    final manager = SqliteSchemaManager(
      database,
      tables: tables,
      migrationsDir: migrationsDir,
    );

    try {
      final command = args.isNotEmpty ? args.first : 'help';

      switch (command) {
        case 'status':
          await _status(manager);
        case 'diff':
          await _diff(manager);
        case 'generate':
          await _generate(manager);
        case 'apply':
          final dryRun = args.contains('--dry-run');
          await _apply(manager, dryRun: dryRun);
        case 'help':
          _help();
        default:
          stderr.writeln('Unknown command: $command');
          _help();
          exit(1);
      }
    } finally {
      if (db == null) await database.close();
    }
  }

  static Future<void> _status(SqliteSchemaManager manager) async {
    final statuses = await manager.status();
    if (statuses.isEmpty) {
      // ignore: avoid_print
      print('No migrations found.');
      return;
    }
    for (final s in statuses) {
      final tag = s.applied ? 'applied' : 'pending';
      final ts = s.appliedAt != null ? '  (${s.appliedAt})' : '';
      // ignore: avoid_print
      print('[$tag] ${s.filename}$ts');
    }
  }

  static Future<void> _diff(SqliteSchemaManager manager) async {
    final ops = await manager.diff();
    if (ops.isEmpty) {
      // ignore: avoid_print
      print('Schema is up-to-date.');
      return;
    }
    // ignore: avoid_print
    print('Changes detected:');
    for (final op in ops) {
      // ignore: avoid_print
      print('  ${_describeOp(op)}');
    }
  }

  static Future<void> _generate(SqliteSchemaManager manager) async {
    final path = await manager.generate();
    if (path == null) {
      // ignore: avoid_print
      print('Schema is up-to-date. No migration generated.');
      return;
    }
    // ignore: avoid_print
    print('Generated migration: $path');
  }

  static Future<void> _apply(
    SqliteSchemaManager manager, {
    required bool dryRun,
  }) async {
    final applied = await manager.apply(dryRun: dryRun);
    if (applied.isEmpty) {
      // ignore: avoid_print
      print('No pending migrations.');
      return;
    }
    final prefix = dryRun ? 'Would apply' : 'Applied';
    for (final name in applied) {
      // ignore: avoid_print
      print('$prefix: $name');
    }
  }

  static void _help() {
    // ignore: avoid_print
    print('''
Stanza SQLite Migration CLI

Commands:
  status      Show applied and pending migrations
  diff        Show schema changes (code vs database)
  generate    Generate a migration file from the diff
  apply       Apply all pending migrations
  apply --dry-run  Show SQL without executing
  help        Show this help message

Usage:
  dart run bin/migrate.dart <command>''');
  }

  static String _describeOp(SchemaDiffOp op) => switch (op) {
        CreateTable(:final table) => 'CREATE TABLE ${table.name}',
        AddColumn(:final tableName, :final column) =>
          'ADD COLUMN $tableName.${column.name} (${column.type.value})',
        AlterColumnType(:final tableName, :final columnName, :final newType) =>
          'ALTER COLUMN $tableName.$columnName TYPE $newType (requires table rebuild)',
        AlterColumnNullability(
          :final tableName,
          :final columnName,
          :final nullable,
        ) =>
          'ALTER COLUMN $tableName.$columnName '
              '${nullable ? "DROP NOT NULL" : "SET NOT NULL"} (requires table rebuild)',
        AlterColumnDefault(
          :final tableName,
          :final columnName,
          :final newDefault,
        ) =>
          newDefault != null
              ? 'ALTER COLUMN $tableName.$columnName SET DEFAULT $newDefault (requires table rebuild)'
              : 'ALTER COLUMN $tableName.$columnName DROP DEFAULT (requires table rebuild)',
        AddConstraint(:final tableName, :final constraint) =>
          'ADD CONSTRAINT ${constraint.name} on $tableName (requires table rebuild)',
        DropColumn(:final tableName, :final columnName) =>
          'DROP COLUMN $tableName.$columnName (commented for safety)',
        DropConstraint(:final tableName, :final constraintName) =>
          'DROP CONSTRAINT $constraintName on $tableName (requires table rebuild)',
      };
}
