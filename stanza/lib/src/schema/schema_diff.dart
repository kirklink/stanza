import 'schema_column.dart';
import 'schema_constraint.dart';
import 'schema_table.dart';

/// A sealed hierarchy of DDL operations produced by schema diffing.
///
/// Each subclass represents a specific DDL change and can generate its SQL.
sealed class SchemaDiffOp {
  const SchemaDiffOp();

  /// Generates the PostgreSQL DDL statement for this operation.
  String toSql();
}

/// Creates a new table with all its columns and constraints.
class CreateTable extends SchemaDiffOp {
  /// The complete table schema to create.
  final SchemaTable table;

  /// Creates an operation to create the given [table].
  const CreateTable(this.table);

  @override
  String toSql() {
    final buf = StringBuffer();
    buf.write('CREATE TABLE ${table.name} (\n');

    final parts = <String>[];

    for (final col in table.columns) {
      final colBuf = StringBuffer('  ${col.name} ');
      colBuf.write(col.type.value);
      if (!col.nullable) colBuf.write(' NOT NULL');
      if (col.defaultValue != null) colBuf.write(' DEFAULT ${col.defaultValue}');
      parts.add(colBuf.toString());
    }

    for (final constraint in table.constraints) {
      parts.add('  ${_constraintSql(constraint)}');
    }

    buf.write(parts.join(',\n'));
    buf.write('\n);');
    return buf.toString();
  }
}

/// Adds a column to an existing table.
class AddColumn extends SchemaDiffOp {
  /// The target table name.
  final String tableName;

  /// The column definition to add.
  final SchemaColumn column;

  /// Creates an operation to add [column] to [tableName].
  const AddColumn(this.tableName, this.column);

  @override
  String toSql() {
    final buf = StringBuffer('ALTER TABLE $tableName ADD COLUMN ${column.name} ');
    buf.write(column.type.value);
    if (!column.nullable) buf.write(' NOT NULL');
    if (column.defaultValue != null) {
      buf.write(' DEFAULT ${column.defaultValue}');
    }
    buf.write(';');
    return buf.toString();
  }
}

/// Changes a column's type.
class AlterColumnType extends SchemaDiffOp {
  /// The target table name.
  final String tableName;

  /// The column to alter.
  final String columnName;

  /// The new PostgreSQL type (e.g. `'text'`, `'integer'`).
  final String newType;

  /// Creates an operation to change [columnName] in [tableName] to [newType].
  const AlterColumnType(this.tableName, this.columnName, this.newType);

  @override
  String toSql() =>
      'ALTER TABLE $tableName ALTER COLUMN $columnName TYPE $newType;';
}

/// Changes a column's nullability.
class AlterColumnNullability extends SchemaDiffOp {
  /// The target table name.
  final String tableName;

  /// The column to alter.
  final String columnName;

  /// Whether the column should allow NULLs after the migration.
  final bool nullable;

  /// Creates an operation to set [columnName] in [tableName] to [nullable].
  const AlterColumnNullability(this.tableName, this.columnName, this.nullable);

  @override
  String toSql() => nullable
      ? 'ALTER TABLE $tableName ALTER COLUMN $columnName DROP NOT NULL;'
      : 'ALTER TABLE $tableName ALTER COLUMN $columnName SET NOT NULL;';
}

/// Changes a column's default value.
class AlterColumnDefault extends SchemaDiffOp {
  /// The target table name.
  final String tableName;

  /// The column to alter.
  final String columnName;

  /// The new SQL DEFAULT expression, or null to drop the default.
  final String? newDefault;

  /// Creates an operation to change the default of [columnName] in [tableName].
  const AlterColumnDefault(this.tableName, this.columnName, this.newDefault);

  @override
  String toSql() => newDefault != null
      ? 'ALTER TABLE $tableName ALTER COLUMN $columnName SET DEFAULT $newDefault;'
      : 'ALTER TABLE $tableName ALTER COLUMN $columnName DROP DEFAULT;';
}

/// Adds a constraint to an existing table.
class AddConstraint extends SchemaDiffOp {
  /// The target table name.
  final String tableName;

  /// The constraint to add (PK, unique, or FK).
  final SchemaConstraint constraint;

  /// Creates an operation to add [constraint] to [tableName].
  const AddConstraint(this.tableName, this.constraint);

  @override
  String toSql() =>
      'ALTER TABLE $tableName ADD ${_constraintSql(constraint)};';
}

/// Drops a column (commented out for safety — manual review required).
class DropColumn extends SchemaDiffOp {
  /// The target table name.
  final String tableName;

  /// The column to drop.
  final String columnName;

  /// Creates an operation to drop [columnName] from [tableName].
  const DropColumn(this.tableName, this.columnName);

  @override
  String toSql() =>
      '-- SAFETY: ALTER TABLE $tableName DROP COLUMN $columnName;';
}

/// Drops a constraint.
class DropConstraint extends SchemaDiffOp {
  /// The target table name.
  final String tableName;

  /// The constraint name to drop (e.g. `'users_email_key'`).
  final String constraintName;

  /// Creates an operation to drop [constraintName] from [tableName].
  const DropConstraint(this.tableName, this.constraintName);

  @override
  String toSql() =>
      'ALTER TABLE $tableName DROP CONSTRAINT $constraintName;';
}

/// Generates the CONSTRAINT clause SQL for inline use in CREATE TABLE
/// or ADD CONSTRAINT.
String _constraintSql(SchemaConstraint c) {
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

/// Computes the DDL operations needed to migrate [actual] schema to [expected].
class SchemaDiff {
  /// Diffs a single table: returns the operations to transform [actual]
  /// into [expected].
  ///
  /// If [actual] is null, the table doesn't exist and a [CreateTable] is returned.
  static List<SchemaDiffOp> diff(SchemaTable expected, SchemaTable? actual) {
    if (actual == null) return [CreateTable(expected)];

    final ops = <SchemaDiffOp>[];

    // Column diffs
    final actualColNames = {for (final c in actual.columns) c.name};
    final expectedColNames = {for (final c in expected.columns) c.name};

    for (final col in expected.columns) {
      final actualCol = actual.columnByName(col.name);
      if (actualCol == null) {
        // New column
        ops.add(AddColumn(expected.name, col));
        continue;
      }

      // Type change (respecting serial/integer equivalence)
      if (!col.type.isEquivalentTo(actualCol.type)) {
        ops.add(AlterColumnType(expected.name, col.name, col.type.value));
      }

      // Nullability change
      if (col.nullable != actualCol.nullable) {
        ops.add(
          AlterColumnNullability(expected.name, col.name, col.nullable),
        );
      }

      // Default change (skip serial columns — nextval is implicit)
      if (!col.isSerial && col.defaultValue != actualCol.defaultValue) {
        ops.add(AlterColumnDefault(expected.name, col.name, col.defaultValue));
      }
    }

    // Removed columns (commented out for safety)
    for (final colName in actualColNames) {
      if (!expectedColNames.contains(colName)) {
        ops.add(DropColumn(expected.name, colName));
      }
    }

    // Constraint diffs
    final actualConstraintNames = {
      for (final c in actual.constraints) c.name,
    };
    final expectedConstraintNames = {
      for (final c in expected.constraints) c.name,
    };

    for (final constraint in expected.constraints) {
      if (!actualConstraintNames.contains(constraint.name)) {
        ops.add(AddConstraint(expected.name, constraint));
      }
    }

    for (final constraintName in actualConstraintNames) {
      if (!expectedConstraintNames.contains(constraintName)) {
        ops.add(DropConstraint(expected.name, constraintName));
      }
    }

    return ops;
  }
}
