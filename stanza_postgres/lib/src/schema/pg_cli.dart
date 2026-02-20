import 'dart:io';

import 'package:stanza/stanza.dart';

import '../postgres_database.dart';
import 'pg_schema_manager.dart';

/// CLI helper for schema management commands.
///
/// Usage in a project's `bin/migrate.dart`:
/// ```dart
/// void main(List<String> args) => PgCli.run(
///   args,
///   databaseUrl: Platform.environment['DATABASE_URL']!,
///   tables: [userTable, postTable],
/// );
/// ```
class PgCli {
  /// Runs the CLI with the given arguments.
  ///
  /// Provide either [databaseUrl] or [db], not both.
  static Future<void> run(
    List<String> args, {
    String? databaseUrl,
    DatabaseAdapter? db,
    required List<TableDescriptor> tables,
    String migrationsDir = 'migrations',
  }) async {
    assert(
      (databaseUrl != null) ^ (db != null),
      'Provide either databaseUrl or db, not both',
    );

    final database = db ?? Stanza.url(databaseUrl!);
    final manager = PgSchemaManager(
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

  static Future<void> _status(PgSchemaManager manager) async {
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

  static Future<void> _diff(PgSchemaManager manager) async {
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

  static Future<void> _generate(PgSchemaManager manager) async {
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
    PgSchemaManager manager, {
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
Stanza PostgreSQL Migration CLI

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
          'ALTER COLUMN $tableName.$columnName TYPE $newType',
        AlterColumnNullability(
          :final tableName,
          :final columnName,
          :final nullable,
        ) =>
          'ALTER COLUMN $tableName.$columnName ${nullable ? "DROP NOT NULL" : "SET NOT NULL"}',
        AlterColumnDefault(
          :final tableName,
          :final columnName,
          :final newDefault,
        ) =>
          newDefault != null
              ? 'ALTER COLUMN $tableName.$columnName SET DEFAULT $newDefault'
              : 'ALTER COLUMN $tableName.$columnName DROP DEFAULT',
        AddConstraint(:final tableName, :final constraint) =>
          'ADD CONSTRAINT ${constraint.name} on $tableName',
        DropColumn(:final tableName, :final columnName) =>
          'DROP COLUMN $tableName.$columnName (commented for safety)',
        DropConstraint(:final tableName, :final constraintName) =>
          'DROP CONSTRAINT $constraintName on $tableName',
      };
}
