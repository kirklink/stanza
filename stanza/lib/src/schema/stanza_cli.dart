import 'dart:io';

import '../stanza.dart';
import '../table.dart';
import 'schema_diff.dart';
import 'schema_manager.dart';

/// A reusable CLI helper for schema management commands.
///
/// Users create a minimal `bin/migrate.dart` script in their project
/// that passes their tables and database URL, then delegates to this class:
///
/// ```dart
/// import 'package:stanza/stanza.dart';
/// import 'package:stanza/schema.dart';
/// import 'package:my_app/models.dart';
///
/// void main(List<String> args) => StanzaCli.run(
///   args,
///   databaseUrl: Platform.environment['DATABASE_URL']!,
///   tables: [Owner.$table, Animal.$table],
/// );
/// ```
///
/// Then run with:
/// ```bash
/// dart run bin/migrate.dart status
/// dart run bin/migrate.dart diff
/// dart run bin/migrate.dart generate
/// dart run bin/migrate.dart apply
/// dart run bin/migrate.dart apply --dry-run
/// ```
class StanzaCli {
  final SchemaManager _manager;

  StanzaCli._(this._manager);

  /// Entry point — parses args, runs the command, exits.
  ///
  /// Provide either [databaseUrl] or [stanza] (not both).
  /// If [databaseUrl] is given, a connection is created and closed automatically.
  static Future<void> run(
    List<String> args, {
    String? databaseUrl,
    Stanza? stanza,
    required List<Table> tables,
    String migrationsDir = 'migrations',
  }) async {
    if (databaseUrl == null && stanza == null) {
      _printError('Either databaseUrl or stanza instance must be provided.');
      _printUsage();
      exit(1);
    }

    final command = args.firstOrNull ?? 'help';
    final flags = args.skip(1).toSet();

    if (command == 'help' || command == '--help' || command == '-h') {
      _printUsage();
      return;
    }

    final db = stanza ?? Stanza.url(databaseUrl!);
    final manager = SchemaManager(
      db,
      tables: tables,
      migrationsDir: migrationsDir,
    );
    final cli = StanzaCli._(manager);

    try {
      switch (command) {
        case 'status':
          await cli._status();
        case 'diff':
          await cli._diff();
        case 'generate':
          await cli._generate();
        case 'apply':
          await cli._apply(dryRun: flags.contains('--dry-run'));
        default:
          _printError('Unknown command: $command');
          _printUsage();
          exit(1);
      }
    } finally {
      if (stanza == null) {
        await db.close();
      }
    }
  }

  Future<void> _status() async {
    final statuses = await _manager.status();
    if (statuses.isEmpty) {
      stdout.writeln('No migration files found.');
      return;
    }

    stdout.writeln('Migration status:');
    stdout.writeln('');
    for (final s in statuses) {
      final icon = s.applied ? '[applied]' : '[pending] ';
      final time = s.appliedAt != null ? '  (${s.appliedAt})' : '';
      stdout.writeln('  $icon ${s.filename}$time');
    }
    stdout.writeln('');

    final pending = statuses.where((s) => !s.applied).length;
    final applied = statuses.where((s) => s.applied).length;
    stdout.writeln('$applied applied, $pending pending.');
  }

  Future<void> _diff() async {
    final ops = await _manager.diff();
    if (ops.isEmpty) {
      stdout.writeln('Schema is up to date. No changes needed.');
      return;
    }

    stdout.writeln('Schema changes detected (${ops.length} operations):');
    stdout.writeln('');
    for (final op in ops) {
      stdout.writeln('  ${_describeOp(op)}');
    }
    stdout.writeln('');
    stdout.writeln('Run "generate" to create a migration file.');
  }

  Future<void> _generate() async {
    final path = await _manager.generate();
    if (path == null) {
      stdout.writeln('Schema is up to date. Nothing to generate.');
      return;
    }
    stdout.writeln('Generated migration: $path');
  }

  Future<void> _apply({bool dryRun = false}) async {
    if (dryRun) {
      stdout.writeln('Dry run — no changes will be applied:');
      stdout.writeln('');
    }

    final applied = await _manager.apply(dryRun: dryRun);
    if (applied.isEmpty) {
      stdout.writeln('No pending migrations to apply.');
      return;
    }

    if (dryRun) {
      stdout.writeln('');
      stdout.writeln('${applied.length} migration(s) would be applied.');
    } else {
      stdout.writeln('Applied ${applied.length} migration(s):');
      for (final name in applied) {
        stdout.writeln('  $name');
      }
    }
  }

  static String _describeOp(SchemaDiffOp op) {
    return switch (op) {
      CreateTable(table: final t) => 'CREATE TABLE ${t.name}',
      AddColumn(tableName: final t, column: final c) =>
        'ADD COLUMN $t.${c.name} (${c.type})',
      AlterColumnType(
        tableName: final t,
        columnName: final c,
        newType: final nt
      ) =>
        'ALTER COLUMN $t.$c TYPE $nt',
      AlterColumnNullability(
        tableName: final t,
        columnName: final c,
        nullable: final n
      ) =>
        n ? 'ALTER COLUMN $t.$c DROP NOT NULL' : 'ALTER COLUMN $t.$c SET NOT NULL',
      AlterColumnDefault(
        tableName: final t,
        columnName: final c,
        newDefault: final d
      ) =>
        d != null
            ? 'ALTER COLUMN $t.$c SET DEFAULT $d'
            : 'ALTER COLUMN $t.$c DROP DEFAULT',
      AddConstraint(tableName: final t, constraint: final c) =>
        'ADD CONSTRAINT ${c.name} on $t (${c.kind.name})',
      DropColumn(tableName: final t, columnName: final c) =>
        'DROP COLUMN $t.$c (commented out — review manually)',
      DropConstraint(tableName: final t, constraintName: final c) =>
        'DROP CONSTRAINT $c on $t',
    };
  }

  static void _printError(String message) {
    stderr.writeln('Error: $message');
    stderr.writeln('');
  }

  static void _printUsage() {
    stdout.writeln('Stanza Schema Management');
    stdout.writeln('');
    stdout.writeln('Usage: dart run bin/migrate.dart <command> [options]');
    stdout.writeln('');
    stdout.writeln('Commands:');
    stdout.writeln('  status     Show applied and pending migrations');
    stdout.writeln('  diff       Show schema differences (code vs database)');
    stdout.writeln('  generate   Generate a migration .sql file from the diff');
    stdout.writeln('  apply      Apply all pending migration files');
    stdout.writeln('  help       Show this help message');
    stdout.writeln('');
    stdout.writeln('Options:');
    stdout.writeln('  --dry-run  (apply only) Print SQL without executing');
  }
}
