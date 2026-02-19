import 'dart:io';

import '../stanza.dart';
import '../table.dart';
import 'db_introspector.dart';
import 'migration_file.dart';
import 'migration_runner.dart';
import 'schema_constraint.dart';
import 'schema_diff.dart';
import 'schema_table.dart';

/// Orchestrates schema diffing, migration file generation, and migration
/// application for a set of Stanza tables.
///
/// ```dart
/// final manager = SchemaManager(
///   stanza,
///   tables: [Post.$table, Author.$table],
///   migrationsDir: 'migrations',
/// );
///
/// // See what's different between code and database
/// final ops = await manager.diff();
///
/// // Generate a migration file from the diff
/// final path = await manager.generate();
///
/// // Apply pending migrations
/// await manager.apply();
///
/// // Check migration status
/// final statuses = await manager.status();
/// ```
class SchemaManager {
  final Stanza _stanza;
  final List<Table> _tables;
  final String migrationsDir;
  final MigrationFileWriter _fileWriter;
  final MigrationRunner _runner;

  SchemaManager(
    this._stanza, {
    required List<Table> tables,
    this.migrationsDir = 'migrations',
  })  : _tables = tables,
        _fileWriter = const MigrationFileWriter(),
        _runner = MigrationRunner(_stanza, migrationsDir: migrationsDir);

  /// Computes the diff between the expected schema (from code) and the
  /// actual database schema.
  ///
  /// Tables are sorted topologically by FK dependencies so parent tables
  /// appear before children in the resulting operations.
  Future<List<SchemaDiffOp>> diff() async {
    final introspector = DbIntrospector(_stanza);
    final expectedTables = _getExpectedTables();
    final tableNames = expectedTables.map((t) => t.name).toList();
    final actualMap = await introspector.introspect(tableNames);

    // Topologically sort expected tables by FK dependencies
    final sorted = _topologicalSort(expectedTables);

    final ops = <SchemaDiffOp>[];
    for (final expected in sorted) {
      final actual = actualMap[expected.name];
      ops.addAll(SchemaDiff.diff(expected, actual));
    }

    return ops;
  }

  /// Generates a migration file from the current diff.
  ///
  /// Returns the file path, or null if there are no differences.
  Future<String?> generate() async {
    final ops = await diff();
    if (ops.isEmpty) return null;

    final dir = Directory(migrationsDir);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    final filename = _fileWriter.generateFilename();
    final content = _fileWriter.generate(ops);
    final file = File('$migrationsDir/$filename');
    file.writeAsStringSync(content);

    return file.path;
  }

  /// Applies all pending migration files.
  ///
  /// If [dryRun] is true, prints the SQL that would be executed.
  /// Returns the list of applied filenames.
  Future<List<String>> apply({bool dryRun = false}) async {
    return _runner.apply(dryRun: dryRun);
  }

  /// Returns the status of all migration files (applied or pending).
  Future<List<MigrationStatus>> status() async {
    return _runner.status();
  }

  List<SchemaTable> _getExpectedTables() {
    final tables = <SchemaTable>[];
    for (final table in _tables) {
      final schema = table.$schema;
      if (schema != null) {
        tables.add(schema);
      }
    }
    return tables;
  }

  /// Topological sort using Kahn's algorithm.
  ///
  /// Tables that are referenced by FK constraints come before the tables
  /// that reference them. This ensures parent tables are created first.
  List<SchemaTable> _topologicalSort(List<SchemaTable> tables) {
    final tableMap = {for (final t in tables) t.name: t};
    final inDegree = {for (final t in tables) t.name: 0};
    final edges = <String, List<String>>{}; // parent → [children]

    for (final table in tables) {
      for (final constraint in table.constraints) {
        if (constraint.kind == ConstraintKind.foreignKey &&
            constraint.referencedTable != null &&
            tableMap.containsKey(constraint.referencedTable)) {
          // table depends on constraint.referencedTable
          edges
              .putIfAbsent(constraint.referencedTable!, () => [])
              .add(table.name);
          inDegree[table.name] = (inDegree[table.name] ?? 0) + 1;
        }
      }
    }

    // Kahn's algorithm
    final queue = <String>[
      for (final entry in inDegree.entries)
        if (entry.value == 0) entry.key,
    ];
    final sorted = <SchemaTable>[];

    while (queue.isNotEmpty) {
      final name = queue.removeAt(0);
      sorted.add(tableMap[name]!);

      for (final child in (edges[name] ?? [])) {
        inDegree[child] = (inDegree[child] ?? 1) - 1;
        if (inDegree[child] == 0) {
          queue.add(child);
        }
      }
    }

    // If there are cycles or unresolved tables, append them at the end
    for (final table in tables) {
      if (!sorted.any((t) => t.name == table.name)) {
        sorted.add(table);
      }
    }

    return sorted;
  }
}
