import 'package:stanza/stanza.dart';

/// Reads the actual database schema from SQLite using PRAGMA queries.
class SqliteIntrospector {
  final DatabaseAdapter _db;

  SqliteIntrospector(this._db);

  /// Introspects the given table names and returns their schemas.
  ///
  /// Tables that don't exist in the database will have `null` values.
  Future<Map<String, SchemaTable?>> introspect(List<String> tableNames) async {
    if (tableNames.isEmpty) return {};

    final result = <String, SchemaTable?>{};

    for (final tableName in tableNames) {
      // Check if table exists
      final exists = await _db.rawQuery(
        "SELECT name FROM sqlite_master "
        "WHERE type='table' AND name=:name",
        parameters: {'name': tableName},
        mapper: (row) => row['name'] as String,
      );
      if (exists.isEmpty) {
        result[tableName] = null;
        continue;
      }

      // Fetch columns via PRAGMA table_info
      final colRows = await _db.rawQuery(
        'PRAGMA table_info($tableName)',
        mapper: (row) => row,
      );

      // Collect PK columns
      final pkColumns = <String>{};
      for (final row in colRows) {
        if ((row['pk'] as int) > 0) {
          pkColumns.add(row['name'] as String);
        }
      }

      // Fetch unique constraints via PRAGMA index_list + index_info
      final uniqueColumns = <String>{};
      final uniqueConstraints = <SchemaConstraint>[];

      final indexRows = await _db.rawQuery(
        'PRAGMA index_list($tableName)',
        mapper: (row) => row,
      );

      for (final idx in indexRows) {
        final isUnique = (idx['unique'] as int) == 1;
        if (!isUnique) continue;

        final indexName = idx['name'] as String;
        final origin = idx['origin'] as String;

        // Skip autoindex (PK constraints) — they're handled separately
        if (origin == 'pk') continue;

        final infoRows = await _db.rawQuery(
          'PRAGMA index_info($indexName)',
          mapper: (row) => row,
        );

        final columns = <String>[];
        for (final info in infoRows) {
          columns.add(info['name'] as String);
        }

        if (columns.length == 1) {
          uniqueColumns.add(columns.first);
        }

        uniqueConstraints.add(SchemaConstraint(
          name: indexName,
          kind: ConstraintKind.unique,
          columns: columns,
        ));
      }

      // Fetch foreign keys via PRAGMA foreign_key_list
      final fkConstraints = <SchemaConstraint>[];
      final fkRows = await _db.rawQuery(
        'PRAGMA foreign_key_list($tableName)',
        mapper: (row) => row,
      );

      for (final fk in fkRows) {
        final fromCol = fk['from'] as String;
        final refTable = fk['table'] as String;
        final refCol = fk['to'] as String;
        final onDelete = fk['on_delete'] as String;

        fkConstraints.add(SchemaConstraint(
          name: '${tableName}_${fromCol}_fkey',
          kind: ConstraintKind.foreignKey,
          columns: [fromCol],
          referencedTable: refTable,
          referencedColumn: refCol,
          onDelete: onDelete == 'NO ACTION' ? null : onDelete,
        ));
      }

      // Build columns
      final columns = <SchemaColumn>[];
      for (final row in colRows) {
        final colName = row['name'] as String;
        final rawType = (row['type'] as String).toUpperCase().trim();
        final notNull = (row['notnull'] as int) == 1;
        final dfltValue = row['dflt_value'];
        final isPk = pkColumns.contains(colName);
        final isUnique = uniqueColumns.contains(colName);

        // Detect serial: INTEGER PRIMARY KEY (single-column PK, integer type)
        final isSerial = isPk &&
            pkColumns.length == 1 &&
            (rawType == 'INTEGER' || rawType.isEmpty);

        columns.add(SchemaColumn(
          name: colName,
          type: _mapSqliteType(rawType),
          nullable: !notNull && !isPk,
          defaultValue: isSerial ? null : dfltValue?.toString(),
          isPrimaryKey: isPk,
          isSerial: isSerial,
          isUnique: isUnique,
        ));
      }

      // Build constraints list
      final constraints = <SchemaConstraint>[];

      // PK constraint
      if (pkColumns.isNotEmpty) {
        constraints.add(SchemaConstraint(
          name: '${tableName}_pkey',
          kind: ConstraintKind.primaryKey,
          columns: pkColumns.toList(),
        ));
      }

      constraints.addAll(uniqueConstraints);
      constraints.addAll(fkConstraints);

      result[tableName] = SchemaTable(
        name: tableName,
        columns: columns,
        constraints: constraints,
      );
    }

    return result;
  }

  /// Checks whether an FTS5 virtual table exists in the database.
  Future<bool> fts5TableExists(String tableName) async {
    final rows = await _db.rawQuery(
      "SELECT sql FROM sqlite_master "
      "WHERE type='table' AND name=:name AND sql LIKE '%fts5%'",
      parameters: {'name': tableName},
      mapper: (row) => row['sql'] as String,
    );
    return rows.isNotEmpty;
  }

  /// Maps SQLite type strings to canonical [ColumnType] values.
  static ColumnType _mapSqliteType(String sqliteType) {
    final upper = sqliteType.toUpperCase().trim();
    return switch (upper) {
      'INTEGER' || 'INT' || 'BIGINT' || 'SMALLINT' || 'TINYINT' =>
        const ColumnType('integer'),
      'REAL' || 'DOUBLE' || 'FLOAT' || 'DOUBLE PRECISION' =>
        const ColumnType('double precision'),
      'TEXT' || 'VARCHAR' || 'CHAR' || 'CLOB' => const ColumnType('text'),
      'BLOB' => const ColumnType('bytea'),
      '' => const ColumnType('integer'), // SQLite default affinity
      _ => () {
          // Handle VARCHAR(N) pattern
          if (upper.startsWith('VARCHAR(')) {
            return const ColumnType('text');
          }
          return ColumnType(sqliteType.toLowerCase());
        }(),
    };
  }
}
