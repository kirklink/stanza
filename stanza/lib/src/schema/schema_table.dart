import 'schema_column.dart';
import 'schema_constraint.dart';

/// Represents a full database table schema (columns + constraints).
class SchemaTable {
  final String name;
  final List<SchemaColumn> columns;
  final List<SchemaConstraint> constraints;

  const SchemaTable({
    required this.name,
    required this.columns,
    this.constraints = const [],
  });

  /// Finds a column by name, or returns null.
  SchemaColumn? columnByName(String name) {
    for (final col in columns) {
      if (col.name == name) return col;
    }
    return null;
  }

  /// Conventional PK constraint name: `<table>_pkey`.
  String get primaryKeyConstraintName => '${name}_pkey';

  /// Conventional unique constraint name: `<table>_<col>_key`.
  String uniqueConstraintName(String col) => '${name}_${col}_key';

  /// Conventional FK constraint name: `<table>_<col>_fkey`.
  String foreignKeyConstraintName(String col) => '${name}_${col}_fkey';

  @override
  String toString() =>
      'SchemaTable($name, ${columns.length} columns, ${constraints.length} constraints)';
}
