import '../stanza.dart';
import 'column_type.dart';
import 'schema_column.dart';
import 'schema_constraint.dart';
import 'schema_table.dart';

/// Reads the actual database schema from PostgreSQL `information_schema`.
class DbIntrospector {
  final Stanza _db;

  DbIntrospector(this._db);

  /// Introspects the given table names and returns their schemas.
  ///
  /// Tables that don't exist in the database will have `null` values.
  Future<Map<String, SchemaTable?>> introspect(List<String> tableNames) async {
    if (tableNames.isEmpty) return {};

    final placeholders = <String>[];
    final params = <String, dynamic>{};
    for (var i = 0; i < tableNames.length; i++) {
      placeholders.add('@t$i');
      params['t$i'] = tableNames[i];
    }
    final inClause = placeholders.join(', ');

    // 1. Fetch columns
    final colResult = await _db.rawExecute(
      'SELECT table_name, column_name, udt_name, is_nullable, '
      'column_default, character_maximum_length '
      'FROM information_schema.columns '
      "WHERE table_schema = 'public' AND table_name IN ($inClause) "
      'ORDER BY table_name, ordinal_position',
      parameters: params,
    );

    // 2. Fetch PK + unique constraints
    final pkUqResult = await _db.rawExecute(
      'SELECT tc.table_name, tc.constraint_name, tc.constraint_type, '
      'kcu.column_name '
      'FROM information_schema.table_constraints tc '
      'JOIN information_schema.key_column_usage kcu '
      'ON tc.constraint_name = kcu.constraint_name '
      'AND tc.table_schema = kcu.table_schema '
      "WHERE tc.constraint_type IN ('PRIMARY KEY', 'UNIQUE') "
      "AND tc.table_schema = 'public' AND tc.table_name IN ($inClause)",
      parameters: params,
    );

    // 3. Fetch foreign keys
    final fkResult = await _db.rawExecute(
      'SELECT tc.table_name, tc.constraint_name, kcu.column_name, '
      'ccu.table_name AS referenced_table, '
      'ccu.column_name AS referenced_column, rc.delete_rule '
      'FROM information_schema.table_constraints tc '
      'JOIN information_schema.key_column_usage kcu '
      'ON tc.constraint_name = kcu.constraint_name '
      'AND tc.table_schema = kcu.table_schema '
      'JOIN information_schema.constraint_column_usage ccu '
      'ON tc.constraint_name = ccu.constraint_name '
      'AND tc.table_schema = ccu.table_schema '
      'JOIN information_schema.referential_constraints rc '
      'ON tc.constraint_name = rc.constraint_name '
      'AND tc.table_schema = rc.constraint_schema '
      "WHERE tc.constraint_type = 'FOREIGN KEY' "
      "AND tc.table_schema = 'public' AND tc.table_name IN ($inClause)",
      parameters: params,
    );

    // Group PK/unique constraints by table + constraint name
    final constraintBuilders = <String, Map<String, _ConstraintBuilder>>{};
    for (final row in pkUqResult.rows) {
      final table = row['table_name'] as String;
      final name = row['constraint_name'] as String;
      final type = row['constraint_type'] as String;
      final column = row['column_name'] as String;

      constraintBuilders.putIfAbsent(table, () => {});
      final builder = constraintBuilders[table]!.putIfAbsent(
        name,
        () => _ConstraintBuilder(
          name: name,
          kind: type == 'PRIMARY KEY'
              ? ConstraintKind.primaryKey
              : ConstraintKind.unique,
        ),
      );
      builder.columns.add(column);
    }

    // Collect PK column names per table for column flags
    final pkColumns = <String, Set<String>>{};
    final uniqueColumns = <String, Set<String>>{};
    for (final entry in constraintBuilders.entries) {
      for (final cb in entry.value.values) {
        if (cb.kind == ConstraintKind.primaryKey) {
          pkColumns.putIfAbsent(entry.key, () => {}).addAll(cb.columns);
        } else if (cb.kind == ConstraintKind.unique && cb.columns.length == 1) {
          uniqueColumns.putIfAbsent(entry.key, () => {}).add(cb.columns.first);
        }
      }
    }

    // Build FK constraints
    final fkConstraints = <String, List<SchemaConstraint>>{};
    for (final row in fkResult.rows) {
      final table = row['table_name'] as String;
      final name = row['constraint_name'] as String;
      final column = row['column_name'] as String;
      final refTable = row['referenced_table'] as String;
      final refColumn = row['referenced_column'] as String;
      final deleteRule = row['delete_rule'] as String;

      fkConstraints.putIfAbsent(table, () => []).add(SchemaConstraint(
        name: name,
        kind: ConstraintKind.foreignKey,
        columns: [column],
        referencedTable: refTable,
        referencedColumn: refColumn,
        onDelete: deleteRule == 'NO ACTION' ? null : deleteRule,
      ));
    }

    // Group columns by table
    final tableColumns = <String, List<SchemaColumn>>{};
    for (final row in colResult.rows) {
      final table = row['table_name'] as String;
      final colName = row['column_name'] as String;
      final udtName = row['udt_name'] as String;
      final isNullable = row['is_nullable'] as String;
      final colDefault = row['column_default'] as String?;
      final charMaxLen = row['character_maximum_length']?.toString();

      final isSerialCol =
          colDefault != null && colDefault.contains('nextval(');
      final isPk = pkColumns[table]?.contains(colName) ?? false;
      final isUnique = uniqueColumns[table]?.contains(colName) ?? false;

      tableColumns.putIfAbsent(table, () => []).add(SchemaColumn(
        name: colName,
        type: ColumnType.fromUdtName(udtName, charMaxLength: charMaxLen),
        nullable: isNullable == 'YES',
        defaultValue: isSerialCol ? null : colDefault,
        isPrimaryKey: isPk,
        isSerial: isSerialCol,
        isUnique: isUnique,
      ));
    }

    // Build result map
    final result = <String, SchemaTable?>{};
    for (final name in tableNames) {
      final cols = tableColumns[name];
      if (cols == null) {
        result[name] = null;
        continue;
      }

      final allConstraints = <SchemaConstraint>[];

      // PK + unique constraints
      final builders = constraintBuilders[name];
      if (builders != null) {
        for (final cb in builders.values) {
          allConstraints.add(SchemaConstraint(
            name: cb.name,
            kind: cb.kind,
            columns: cb.columns,
          ));
        }
      }

      // FK constraints
      final fks = fkConstraints[name];
      if (fks != null) allConstraints.addAll(fks);

      result[name] = SchemaTable(
        name: name,
        columns: cols,
        constraints: allConstraints,
      );
    }

    return result;
  }
}

class _ConstraintBuilder {
  final String name;
  final ConstraintKind kind;
  final List<String> columns = [];

  _ConstraintBuilder({required this.name, required this.kind});
}
