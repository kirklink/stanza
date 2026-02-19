import '../stanza.dart';
import 'column_type.dart';
import 'schema_column.dart';
import 'schema_constraint.dart';
import 'schema_table.dart';

/// Queries PostgreSQL `information_schema` to build [SchemaTable] representations
/// of existing database tables.
///
/// Only introspects the table names you pass in — not the entire database.
class DbIntrospector {
  final Stanza _stanza;

  const DbIntrospector(this._stanza);

  /// Introspects the given [tableNames] and returns a map from table name
  /// to [SchemaTable] (or null if the table doesn't exist).
  Future<Map<String, SchemaTable?>> introspect(List<String> tableNames) async {
    if (tableNames.isEmpty) return {};

    final result = <String, SchemaTable?>{};
    for (final name in tableNames) {
      result[name] = null;
    }

    // ── 1. Columns ──
    final columns = await _queryColumns(tableNames);

    // ── 2. PK + Unique constraints ──
    final pkAndUnique = await _queryPkAndUnique(tableNames);

    // ── 3. Foreign keys ──
    final foreignKeys = await _queryForeignKeys(tableNames);

    // ── Build SchemaTable for each table that exists ──
    for (final tableName in tableNames) {
      final tableCols = columns[tableName];
      if (tableCols == null || tableCols.isEmpty) continue;

      // Find PK columns to mark on SchemaColumn
      final pkColNames = <String>{};
      for (final c in (pkAndUnique[tableName] ?? [])) {
        if (c.kind == ConstraintKind.primaryKey) {
          pkColNames.addAll(c.columns);
        }
      }

      final uniqueColNames = <String>{};
      for (final c in (pkAndUnique[tableName] ?? [])) {
        if (c.kind == ConstraintKind.unique && c.columns.length == 1) {
          uniqueColNames.add(c.columns.first);
        }
      }

      final schemaCols = tableCols.map((raw) {
        final name = raw['name'] as String;
        return SchemaColumn(
          name: name,
          type: raw['type'] as ColumnType,
          nullable: raw['nullable'] as bool,
          defaultValue: raw['default'] as String?,
          isPrimaryKey: pkColNames.contains(name),
          isSerial: raw['isSerial'] as bool,
          isUnique: uniqueColNames.contains(name),
        );
      }).toList();

      final constraints = <SchemaConstraint>[
        ...(pkAndUnique[tableName] ?? []),
        ...(foreignKeys[tableName] ?? []),
      ];

      result[tableName] = SchemaTable(
        name: tableName,
        columns: schemaCols,
        constraints: constraints,
      );
    }

    return result;
  }

  Future<Map<String, List<Map<String, dynamic>>>> _queryColumns(
      List<String> tableNames) async {
    final placeholders =
        List.generate(tableNames.length, (i) => '@t$i').join(', ');
    final params = <String, dynamic>{
      for (var i = 0; i < tableNames.length; i++) 't$i': tableNames[i],
    };

    final sql = '''
SELECT table_name, column_name, udt_name, is_nullable,
       column_default, character_maximum_length
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name IN ($placeholders)
ORDER BY table_name, ordinal_position
''';

    final rows = await _stanza.rawExecute(sql, parameters: params);
    final result = <String, List<Map<String, dynamic>>>{};

    for (final row in rows) {
      final map = row.toColumnMap();
      final tableName = map['table_name'] as String;
      final udtName = map['udt_name'] as String;
      final charMaxLen = map['character_maximum_length']?.toString();
      final colDefault = map['column_default'] as String?;
      final isSerial =
          colDefault != null && colDefault.contains('nextval(');

      result.putIfAbsent(tableName, () => []).add({
        'name': map['column_name'] as String,
        'type': ColumnType.fromUdtName(udtName, charMaxLength: charMaxLen),
        'nullable': (map['is_nullable'] as String) == 'YES',
        'default': isSerial ? null : colDefault,
        'isSerial': isSerial,
      });
    }
    return result;
  }

  Future<Map<String, List<SchemaConstraint>>> _queryPkAndUnique(
      List<String> tableNames) async {
    final placeholders =
        List.generate(tableNames.length, (i) => '@t$i').join(', ');
    final params = <String, dynamic>{
      for (var i = 0; i < tableNames.length; i++) 't$i': tableNames[i],
    };

    final sql = '''
SELECT tc.table_name, tc.constraint_name, tc.constraint_type,
       kcu.column_name
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
  ON tc.constraint_name = kcu.constraint_name
  AND tc.table_schema = kcu.table_schema
WHERE tc.table_schema = 'public'
  AND tc.table_name IN ($placeholders)
  AND tc.constraint_type IN ('PRIMARY KEY', 'UNIQUE')
ORDER BY tc.table_name, tc.constraint_name, kcu.ordinal_position
''';

    final rows = await _stanza.rawExecute(sql, parameters: params);
    final grouped = <String, Map<String, _ConstraintBuilder>>{};

    for (final row in rows) {
      final map = row.toColumnMap();
      final tableName = map['table_name'] as String;
      final constraintName = map['constraint_name'] as String;
      final constraintType = map['constraint_type'] as String;
      final columnName = map['column_name'] as String;

      grouped.putIfAbsent(tableName, () => {});
      grouped[tableName]!.putIfAbsent(
        constraintName,
        () => _ConstraintBuilder(
          constraintName,
          constraintType == 'PRIMARY KEY'
              ? ConstraintKind.primaryKey
              : ConstraintKind.unique,
        ),
      );
      grouped[tableName]![constraintName]!.columns.add(columnName);
    }

    return grouped.map((tableName, builders) => MapEntry(
          tableName,
          builders.values
              .map((b) => SchemaConstraint(
                    name: b.name,
                    kind: b.kind,
                    columns: b.columns,
                  ))
              .toList(),
        ));
  }

  Future<Map<String, List<SchemaConstraint>>> _queryForeignKeys(
      List<String> tableNames) async {
    final placeholders =
        List.generate(tableNames.length, (i) => '@t$i').join(', ');
    final params = <String, dynamic>{
      for (var i = 0; i < tableNames.length; i++) 't$i': tableNames[i],
    };

    final sql = '''
SELECT tc.table_name, tc.constraint_name,
       kcu.column_name,
       ccu.table_name AS referenced_table,
       ccu.column_name AS referenced_column,
       rc.delete_rule
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
  ON tc.constraint_name = kcu.constraint_name
  AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage ccu
  ON tc.constraint_name = ccu.constraint_name
  AND tc.table_schema = ccu.table_schema
JOIN information_schema.referential_constraints rc
  ON tc.constraint_name = rc.constraint_name
  AND tc.table_schema = rc.constraint_schema
WHERE tc.table_schema = 'public'
  AND tc.table_name IN ($placeholders)
  AND tc.constraint_type = 'FOREIGN KEY'
ORDER BY tc.table_name, tc.constraint_name
''';

    final rows = await _stanza.rawExecute(sql, parameters: params);
    final result = <String, List<SchemaConstraint>>{};

    for (final row in rows) {
      final map = row.toColumnMap();
      final tableName = map['table_name'] as String;
      final deleteRule = map['delete_rule'] as String;

      result.putIfAbsent(tableName, () => []).add(SchemaConstraint(
            name: map['constraint_name'] as String,
            kind: ConstraintKind.foreignKey,
            columns: [map['column_name'] as String],
            referencedTable: map['referenced_table'] as String,
            referencedColumn: map['referenced_column'] as String,
            onDelete: deleteRule == 'NO ACTION' ? null : deleteRule,
          ));
    }

    return result;
  }
}

class _ConstraintBuilder {
  final String name;
  final ConstraintKind kind;
  final List<String> columns = [];
  _ConstraintBuilder(this.name, this.kind);
}
