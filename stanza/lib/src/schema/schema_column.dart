import 'column_type.dart';

/// Represents a database column in the schema.
///
/// Used for schema introspection, diffing, and migration generation.
class SchemaColumn {
  /// The column name in the database.
  final String name;

  /// The PostgreSQL column type.
  final ColumnType type;

  /// Whether the column allows NULL values.
  final bool nullable;

  /// The SQL DEFAULT expression, if any.
  final String? defaultValue;

  /// Whether this column is part of the primary key.
  final bool isPrimaryKey;

  /// Whether this column uses SERIAL (auto-increment).
  final bool isSerial;

  /// Whether this column has a UNIQUE constraint.
  final bool isUnique;

  const SchemaColumn({
    required this.name,
    required this.type,
    this.nullable = true,
    this.defaultValue,
    this.isPrimaryKey = false,
    this.isSerial = false,
    this.isUnique = false,
  });
}
