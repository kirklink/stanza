import 'schema_column.dart';
import 'schema_constraint.dart';
import 'schema_table.dart';

/// Base class for all schema diff operations.
///
/// Each subclass represents a single DDL change and can generate
/// the corresponding SQL via [toSql].
sealed class SchemaDiffOp {
  const SchemaDiffOp();
  String toSql();
}

/// CREATE TABLE with all columns and constraints.
class CreateTable extends SchemaDiffOp {
  final SchemaTable table;
  const CreateTable(this.table);

  @override
  String toSql() {
    final buf = StringBuffer('CREATE TABLE ${table.name} (\n');
    final parts = <String>[];

    for (final col in table.columns) {
      parts.add('  ${_columnDef(col)}');
    }

    for (final c in table.constraints) {
      parts.add('  ${_constraintDef(c)}');
    }

    buf.write(parts.join(',\n'));
    buf.write('\n);');
    return buf.toString();
  }
}

/// ALTER TABLE ADD COLUMN.
class AddColumn extends SchemaDiffOp {
  final String tableName;
  final SchemaColumn column;
  const AddColumn(this.tableName, this.column);

  @override
  String toSql() {
    return 'ALTER TABLE $tableName ADD COLUMN ${_columnDef(column)};';
  }
}

/// ALTER TABLE ALTER COLUMN SET DATA TYPE.
class AlterColumnType extends SchemaDiffOp {
  final String tableName;
  final String columnName;
  final String newType;
  const AlterColumnType(this.tableName, this.columnName, this.newType);

  @override
  String toSql() {
    return 'ALTER TABLE $tableName ALTER COLUMN $columnName TYPE $newType;';
  }
}

/// ALTER TABLE ALTER COLUMN SET/DROP NOT NULL.
class AlterColumnNullability extends SchemaDiffOp {
  final String tableName;
  final String columnName;
  final bool nullable;
  const AlterColumnNullability(this.tableName, this.columnName, this.nullable);

  @override
  String toSql() {
    if (nullable) {
      return 'ALTER TABLE $tableName ALTER COLUMN $columnName DROP NOT NULL;';
    } else {
      return 'ALTER TABLE $tableName ALTER COLUMN $columnName SET NOT NULL;';
    }
  }
}

/// ALTER TABLE ALTER COLUMN SET DEFAULT / DROP DEFAULT.
class AlterColumnDefault extends SchemaDiffOp {
  final String tableName;
  final String columnName;
  final String? newDefault;
  const AlterColumnDefault(this.tableName, this.columnName, this.newDefault);

  @override
  String toSql() {
    if (newDefault == null) {
      return 'ALTER TABLE $tableName ALTER COLUMN $columnName DROP DEFAULT;';
    }
    return 'ALTER TABLE $tableName ALTER COLUMN $columnName SET DEFAULT $newDefault;';
  }
}

/// ALTER TABLE ADD CONSTRAINT.
class AddConstraint extends SchemaDiffOp {
  final String tableName;
  final SchemaConstraint constraint;
  const AddConstraint(this.tableName, this.constraint);

  @override
  String toSql() {
    return 'ALTER TABLE $tableName ADD ${_constraintDef(constraint)};';
  }
}

/// ALTER TABLE DROP COLUMN (emitted as commented-out safety line).
class DropColumn extends SchemaDiffOp {
  final String tableName;
  final String columnName;
  const DropColumn(this.tableName, this.columnName);

  @override
  String toSql() {
    return '-- SAFETY: ALTER TABLE $tableName DROP COLUMN $columnName;';
  }
}

/// ALTER TABLE DROP CONSTRAINT.
class DropConstraint extends SchemaDiffOp {
  final String tableName;
  final String constraintName;
  const DropConstraint(this.tableName, this.constraintName);

  @override
  String toSql() {
    return 'ALTER TABLE $tableName DROP CONSTRAINT $constraintName;';
  }
}

// ── Helpers ──────────────────────────────────────────────────────────

String _columnDef(SchemaColumn col) {
  final buf = StringBuffer(col.name);
  buf.write(' ${col.type}');
  if (!col.nullable) buf.write(' NOT NULL');
  if (col.defaultValue != null) buf.write(' DEFAULT ${col.defaultValue}');
  return buf.toString();
}

String _constraintDef(SchemaConstraint c) {
  switch (c.kind) {
    case ConstraintKind.primaryKey:
      return 'CONSTRAINT ${c.name} PRIMARY KEY (${c.columns.join(', ')})';
    case ConstraintKind.unique:
      return 'CONSTRAINT ${c.name} UNIQUE (${c.columns.join(', ')})';
    case ConstraintKind.foreignKey:
      final buf = StringBuffer(
          'CONSTRAINT ${c.name} FOREIGN KEY (${c.columns.join(', ')}) '
          'REFERENCES ${c.referencedTable} (${c.referencedColumn})');
      if (c.onDelete != null) buf.write(' ON DELETE ${c.onDelete}');
      return buf.toString();
  }
}

// ── Diff algorithm ──────────────────────────────────────────────────

/// Computes the list of DDL operations needed to bring [actual] in line
/// with [expected].
///
/// If [actual] is null, the table doesn't exist yet and a [CreateTable] is
/// returned. Otherwise, column-level and constraint-level diffs are computed.
class SchemaDiff {
  const SchemaDiff._();

  static List<SchemaDiffOp> diff(SchemaTable expected, SchemaTable? actual) {
    if (actual == null) return [CreateTable(expected)];

    final ops = <SchemaDiffOp>[];

    // ── Column diffs ──

    final actualColNames = {for (final c in actual.columns) c.name};
    final expectedColNames = {for (final c in expected.columns) c.name};

    // New columns
    for (final col in expected.columns) {
      if (!actualColNames.contains(col.name)) {
        ops.add(AddColumn(expected.name, col));
      }
    }

    // Altered columns
    for (final col in expected.columns) {
      final actualCol = actual.columnByName(col.name);
      if (actualCol == null) continue;

      if (!col.type.isEquivalentTo(actualCol.type)) {
        ops.add(AlterColumnType(expected.name, col.name, col.type.value));
      }

      if (col.nullable != actualCol.nullable) {
        ops.add(
            AlterColumnNullability(expected.name, col.name, col.nullable));
      }

      // Default value changes (ignoring serial nextval defaults)
      if (!actualCol.isSerial) {
        final expectedDefault = col.defaultValue;
        final actualDefault = actualCol.defaultValue;
        if (expectedDefault != actualDefault) {
          ops.add(AlterColumnDefault(
              expected.name, col.name, expectedDefault));
        }
      }
    }

    // Dropped columns (commented out for safety)
    for (final col in actual.columns) {
      if (!expectedColNames.contains(col.name)) {
        ops.add(DropColumn(expected.name, col.name));
      }
    }

    // ── Constraint diffs ──

    final actualConstraints = {for (final c in actual.constraints) c.name: c};
    final expectedConstraints = {
      for (final c in expected.constraints) c.name: c
    };

    // New constraints
    for (final entry in expectedConstraints.entries) {
      if (!actualConstraints.containsKey(entry.key)) {
        ops.add(AddConstraint(expected.name, entry.value));
      }
    }

    // Dropped constraints
    for (final entry in actualConstraints.entries) {
      if (!expectedConstraints.containsKey(entry.key)) {
        ops.add(DropConstraint(expected.name, entry.key));
      }
    }

    return ops;
  }
}
