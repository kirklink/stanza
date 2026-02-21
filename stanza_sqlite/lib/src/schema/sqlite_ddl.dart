import 'package:stanza/schema.dart';

import '../fts5.dart';

/// SQLite-specific DDL generation from schema diff operations.
///
/// Handles the differences between PostgreSQL and SQLite DDL syntax:
/// - Type names: `INTEGER`, `REAL`, `TEXT` instead of Postgres-specific types
/// - Auto-increment: `INTEGER PRIMARY KEY` instead of `SERIAL`
/// - Defaults: `datetime('now')` instead of `NOW()`
/// - Limited ALTER TABLE: only `ADD COLUMN` supported (no `ALTER COLUMN`)
class SqliteDdl {
  /// Maps a Dart type name to a SQLite column type.
  ///
  /// Serial (auto-increment) columns use `INTEGER` — the `PRIMARY KEY`
  /// qualifier is added at the column level in [createTable].
  static String columnTypeForDart(
    String dartTypeName, {
    bool isSerial = false,
  }) {
    if (isSerial) return 'INTEGER';
    return switch (dartTypeName) {
      'int' => 'INTEGER',
      'double' => 'REAL',
      'String' => 'TEXT',
      'bool' => 'INTEGER',
      'DateTime' => 'TEXT',
      _ => 'TEXT',
    };
  }

  /// Converts a Postgres-style default value to SQLite syntax.
  ///
  /// Returns `null` if the default should be omitted.
  static String? convertDefault(String? pgDefault, String? dartTypeName) {
    if (pgDefault == null) return null;
    final lower = pgDefault.toLowerCase().trim();
    if (lower == 'now()') return "(datetime('now'))";
    if (dartTypeName == 'bool') {
      if (lower == 'true') return '1';
      if (lower == 'false') return '0';
    }
    return pgDefault;
  }

  /// Resolves the SQLite column type for a [SchemaColumn].
  ///
  /// Uses [dartTypeName] when available (preferred), otherwise falls back
  /// to mapping the Postgres [ColumnType.value] directly.
  static String resolveColumnType(SchemaColumn col) {
    if (col.dartTypeName != null) {
      return columnTypeForDart(col.dartTypeName!, isSerial: col.isSerial);
    }
    // Fallback: map Postgres type names to SQLite equivalents
    final pg = col.type.value.toLowerCase();
    return switch (pg) {
      'serial' || 'integer' || 'int4' || 'smallint' || 'bigint' => 'INTEGER',
      'double precision' || 'float8' || 'real' || 'float4' || 'numeric' =>
        'REAL',
      'boolean' || 'bool' => 'INTEGER',
      'timestamptz' || 'timestamp' || 'date' => 'TEXT',
      _ => 'TEXT',
    };
  }

  /// Generates `CREATE TABLE` DDL for SQLite.
  static String createTable(SchemaTable table) {
    final buf = StringBuffer();
    buf.write('CREATE TABLE ${table.name} (\n');

    final parts = <String>[];

    for (final col in table.columns) {
      final colBuf = StringBuffer('  ${col.name} ');
      final sqlType = resolveColumnType(col);
      colBuf.write(sqlType);

      // Serial PKs: INTEGER PRIMARY KEY (implicit rowid alias)
      if (col.isSerial && col.isPrimaryKey) {
        colBuf.write(' PRIMARY KEY');
      } else {
        if (!col.nullable) colBuf.write(' NOT NULL');
      }

      if (col.isUnique) colBuf.write(' UNIQUE');

      final sqlDefault = convertDefault(col.defaultValue, col.dartTypeName);
      if (sqlDefault != null) colBuf.write(' DEFAULT $sqlDefault');

      parts.add(colBuf.toString());
    }

    // Constraints (skip PK if already handled inline for serial columns)
    for (final constraint in table.constraints) {
      // Skip PK constraint if it's a single-column serial PK (handled inline)
      if (constraint.kind == ConstraintKind.primaryKey &&
          constraint.columns.length == 1) {
        final pkCol = table.columnByName(constraint.columns.first);
        if (pkCol != null && pkCol.isSerial) continue;
      }

      parts.add('  ${_constraintSql(constraint)}');
    }

    buf.write(parts.join(',\n'));
    buf.write('\n);');
    return buf.toString();
  }

  /// Generates `ALTER TABLE ... ADD COLUMN` DDL for SQLite.
  static String addColumn(String tableName, SchemaColumn column) {
    final buf = StringBuffer('ALTER TABLE $tableName ADD COLUMN ${column.name} ');
    buf.write(resolveColumnType(column));
    if (!column.nullable) buf.write(' NOT NULL');
    final sqlDefault = convertDefault(column.defaultValue, column.dartTypeName);
    if (sqlDefault != null) buf.write(' DEFAULT $sqlDefault');
    buf.write(';');
    return buf.toString();
  }

  // -- FTS5 DDL --

  /// Generates `CREATE VIRTUAL TABLE ... USING fts5(...)` DDL.
  ///
  /// Uses external content mode, pointing at [Fts5Index.sourceTable].
  ///
  /// ```dart
  /// SqliteDdl.createFts5Table(Fts5Index(
  ///   sourceTable: 'posts',
  ///   columns: ['title', 'body'],
  ///   tokenize: 'porter unicode61',
  /// ));
  /// ```
  static String createFts5Table(Fts5Index index) {
    final buf = StringBuffer('CREATE VIRTUAL TABLE ${index.tableName} ');
    buf.write('USING fts5(');
    buf.write(index.columns.join(', '));
    buf.write(", content='${index.sourceTable}'");
    buf.write(", content_rowid='${index.contentRowid}'");
    if (index.tokenize != null) {
      buf.write(", tokenize='${index.tokenize}'");
    }
    buf.write(');');
    return buf.toString();
  }

  /// Generates the three sync triggers (INSERT, DELETE, UPDATE) that keep
  /// the FTS5 index in sync with the content table.
  ///
  /// Returns a list of three SQL statements.
  static List<String> createFts5Triggers(Fts5Index index) {
    final fts = index.tableName;
    final src = index.sourceTable;
    final cols = index.columns;
    final rid = index.contentRowid;

    final newCols = cols.map((c) => 'new.$c').join(', ');
    final oldCols = cols.map((c) => 'old.$c').join(', ');
    final colList = cols.join(', ');

    return [
      // AFTER INSERT
      'CREATE TRIGGER ${fts}_ai AFTER INSERT ON $src BEGIN '
          "INSERT INTO $fts(rowid, $colList) VALUES (new.$rid, $newCols); "
          'END;',
      // AFTER DELETE
      'CREATE TRIGGER ${fts}_ad AFTER DELETE ON $src BEGIN '
          "INSERT INTO $fts($fts, rowid, $colList) VALUES ('delete', old.$rid, $oldCols); "
          'END;',
      // AFTER UPDATE
      'CREATE TRIGGER ${fts}_au AFTER UPDATE ON $src BEGIN '
          "INSERT INTO $fts($fts, rowid, $colList) VALUES ('delete', old.$rid, $oldCols); "
          "INSERT INTO $fts(rowid, $colList) VALUES (new.$rid, $newCols); "
          'END;',
    ];
  }

  /// Generates DDL to drop an FTS5 table and its sync triggers.
  ///
  /// Returns a list of SQL statements (3 trigger drops + 1 table drop).
  static List<String> dropFts5Table(Fts5Index index) {
    final fts = index.tableName;
    return [
      'DROP TRIGGER IF EXISTS ${fts}_ai;',
      'DROP TRIGGER IF EXISTS ${fts}_ad;',
      'DROP TRIGGER IF EXISTS ${fts}_au;',
      'DROP TABLE IF EXISTS $fts;',
    ];
  }

  /// Generates a full migration file from [SchemaDiffOp] operations.
  ///
  /// Supported operations: [CreateTable], [AddColumn], [DropColumn] (commented).
  /// Unsupported operations (ALTER COLUMN, ADD/DROP CONSTRAINT) are rendered
  /// as TODO comments — SQLite requires table rebuild for these changes.
  static String generateMigration(List<SchemaDiffOp> ops) {
    final buf = StringBuffer();
    final now = DateTime.now().toUtc().toIso8601String();

    buf.writeln('-- Stanza SQLite migration');
    buf.writeln('-- Generated at $now');
    buf.writeln();
    buf.writeln('BEGIN;');
    buf.writeln();

    for (final op in ops) {
      switch (op) {
        case CreateTable(:final table):
          buf.writeln(createTable(table));
          buf.writeln();
        case AddColumn(:final tableName, :final column):
          buf.writeln(addColumn(tableName, column));
          buf.writeln();
        case DropColumn(:final tableName, :final columnName):
          buf.writeln(
            '-- SAFETY: ALTER TABLE $tableName DROP COLUMN $columnName;',
          );
          buf.writeln();
        case AlterColumnType(:final tableName, :final columnName):
          buf.writeln(
            '-- TODO: ALTER COLUMN $tableName.$columnName TYPE change '
            'requires table rebuild in SQLite.',
          );
          buf.writeln();
        case AlterColumnNullability(:final tableName, :final columnName):
          buf.writeln(
            '-- TODO: ALTER COLUMN $tableName.$columnName nullability change '
            'requires table rebuild in SQLite.',
          );
          buf.writeln();
        case AlterColumnDefault(:final tableName, :final columnName):
          buf.writeln(
            '-- TODO: ALTER COLUMN $tableName.$columnName default change '
            'requires table rebuild in SQLite.',
          );
          buf.writeln();
        case AddConstraint(:final tableName, :final constraint):
          buf.writeln(
            '-- TODO: ADD CONSTRAINT ${constraint.name} on $tableName '
            'requires table rebuild in SQLite.',
          );
          buf.writeln();
        case DropConstraint(:final tableName, :final constraintName):
          buf.writeln(
            '-- TODO: DROP CONSTRAINT $constraintName on $tableName '
            'requires table rebuild in SQLite.',
          );
          buf.writeln();
      }
    }

    buf.writeln('COMMIT;');
    return buf.toString();
  }

  /// Generates a CONSTRAINT clause for use in CREATE TABLE.
  static String _constraintSql(SchemaConstraint c) {
    return switch (c.kind) {
      ConstraintKind.primaryKey =>
        'CONSTRAINT ${c.name} PRIMARY KEY (${c.columns.join(', ')})',
      ConstraintKind.unique =>
        'CONSTRAINT ${c.name} UNIQUE (${c.columns.join(', ')})',
      ConstraintKind.foreignKey => () {
          final buf = StringBuffer(
            'CONSTRAINT ${c.name} FOREIGN KEY (${c.columns.join(', ')}) '
            'REFERENCES ${c.referencedTable} (${c.referencedColumn})',
          );
          if (c.onDelete != null) buf.write(' ON DELETE ${c.onDelete}');
          return buf.toString();
        }(),
    };
  }
}
