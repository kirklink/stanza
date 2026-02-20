import 'dart:io';

import '../stanza.dart';
import '../table.dart';
import 'db_introspector.dart';
import 'migration_file.dart';
import 'migration_runner.dart';
import 'schema_constraint.dart';
import 'schema_diff.dart';
import 'schema_table.dart';

/// Orchestrates schema management: diff, generate, and apply migrations.
///
/// Takes a [Stanza] connection and a list of generated [TableDescriptor]
/// instances that provide `$schema` metadata.
class SchemaManager {
  final Stanza _db;
  final List<TableDescriptor> _tables;
  final String _migrationsDir;

  late final _introspector = DbIntrospector(_db);
  late final _runner = MigrationRunner(_db, migrationsDir: _migrationsDir);

  SchemaManager(
    this._db, {
    required List<TableDescriptor> tables,
    String migrationsDir = 'migrations',
  })  : _tables = tables,
        _migrationsDir = migrationsDir;

  /// Computes the diff between code schema and live database.
  ///
  /// Tables are diffed in topological order (FK parents first).
  Future<List<SchemaDiffOp>> diff() async {
    final expectedSchemas = <SchemaTable>[];
    for (final table in _tables) {
      final schema = table.$schema;
      if (schema != null) expectedSchemas.add(schema);
    }

    if (expectedSchemas.isEmpty) return [];

    // Topologically sort by FK dependencies (parents first)
    final sorted = _topologicalSort(expectedSchemas);

    // Introspect actual schemas
    final tableNames = sorted.map((t) => t.name).toList();
    final actual = await _introspector.introspect(tableNames);

    // Diff each table
    final ops = <SchemaDiffOp>[];
    for (final expected in sorted) {
      ops.addAll(SchemaDiff.diff(expected, actual[expected.name]));
    }

    return ops;
  }

  /// Generates a migration file from the current diff.
  ///
  /// Returns the file path, or null if the schema is up-to-date.
  Future<String?> generate() async {
    final ops = await diff();
    if (ops.isEmpty) return null;

    final dir = Directory(_migrationsDir);
    if (!dir.existsSync()) dir.createSync(recursive: true);

    final filename = MigrationFileWriter.generateFilename();
    final content = MigrationFileWriter.generate(ops);
    final path = '${dir.path}/$filename';
    File(path).writeAsStringSync(content);

    return path;
  }

  /// Applies all pending migrations.
  Future<List<String>> apply({bool dryRun = false}) =>
      _runner.apply(dryRun: dryRun);

  /// Returns the status of all migration files.
  Future<List<MigrationStatus>> status() => _runner.status();

  /// Topologically sorts tables so FK-referenced tables come first.
  ///
  /// Uses Kahn's algorithm. Cycles are appended at the end.
  static List<SchemaTable> _topologicalSort(List<SchemaTable> tables) {
    final byName = {for (final t in tables) t.name: t};
    final inDegree = {for (final t in tables) t.name: 0};

    // Build dependency graph from FK constraints
    for (final table in tables) {
      for (final constraint in table.constraints) {
        if (constraint.kind == ConstraintKind.foreignKey &&
            constraint.referencedTable != null &&
            byName.containsKey(constraint.referencedTable)) {
          inDegree[table.name] = (inDegree[table.name] ?? 0) + 1;
        }
      }
    }

    // Process tables with no dependencies first
    final queue = <String>[
      for (final entry in inDegree.entries)
        if (entry.value == 0) entry.key,
    ];
    final sorted = <SchemaTable>[];
    final visited = <String>{};

    while (queue.isNotEmpty) {
      final name = queue.removeAt(0);
      if (visited.contains(name)) continue;
      visited.add(name);
      sorted.add(byName[name]!);

      // Decrease in-degree of dependents
      for (final table in tables) {
        if (visited.contains(table.name)) continue;
        for (final c in table.constraints) {
          if (c.kind == ConstraintKind.foreignKey &&
              c.referencedTable == name) {
            inDegree[table.name] = (inDegree[table.name] ?? 1) - 1;
            if (inDegree[table.name] == 0) queue.add(table.name);
          }
        }
      }
    }

    // Append any unresolved (cyclic) tables
    for (final table in tables) {
      if (!visited.contains(table.name)) sorted.add(table);
    }

    return sorted;
  }
}
