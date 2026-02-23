import 'column_type.dart';

/// Represents a database column in the schema.
///
/// Used for schema introspection, diffing, and migration generation.
class SchemaColumn {
  /// The column name in the database.
  final String name;

  /// The SQL column type for the current database dialect.
  final ColumnType type;

  /// The original Dart type name (e.g. `'int'`, `'String'`, `'DateTime'`).
  ///
  /// Stored so database adapters can map Dart types to their native SQL types
  /// without needing to reverse-engineer from a specific dialect's type names.
  final String? dartTypeName;

  /// Whether the column allows NULL values.
  final bool nullable;

  /// The SQL DEFAULT expression, if any.
  final String? defaultValue;

  /// Whether this column is part of the primary key.
  final bool isPrimaryKey;

  /// Whether this column uses SERIAL / auto-increment.
  final bool isSerial;

  /// Whether this column has a UNIQUE constraint.
  final bool isUnique;

  /// Creates a schema column with the given [name] and [type].
  const SchemaColumn({
    required this.name,
    required this.type,
    this.dartTypeName,
    this.nullable = true,
    this.defaultValue,
    this.isPrimaryKey = false,
    this.isSerial = false,
    this.isUnique = false,
  });
}
