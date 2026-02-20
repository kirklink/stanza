import 'schema_column.dart';
import 'schema_constraint.dart';

/// Represents a complete database table schema.
///
/// Used for both expected schema (from code) and actual schema (from introspection).
class SchemaTable {
  /// The table name.
  final String name;

  /// All columns in the table.
  final List<SchemaColumn> columns;

  /// All constraints (PK, unique, FK).
  final List<SchemaConstraint> constraints;

  const SchemaTable({
    required this.name,
    required this.columns,
    this.constraints = const [],
  });

  /// Finds a column by name, or null if not found.
  SchemaColumn? columnByName(String name) {
    for (final col in columns) {
      if (col.name == name) return col;
    }
    return null;
  }

  /// Conventional primary key constraint name.
  String get primaryKeyConstraintName => '${name}_pkey';

  /// Conventional unique constraint name for a column.
  String uniqueConstraintName(String columnName) =>
      '${name}_${columnName}_key';

  /// Conventional foreign key constraint name for a column.
  String foreignKeyConstraintName(String columnName) =>
      '${name}_${columnName}_fkey';
}
