import 'column_type.dart';

/// Represents a single column in a database table schema.
class SchemaColumn {
  final String name;
  final ColumnType type;
  final bool nullable;
  final String? defaultValue;
  final bool isPrimaryKey;
  final bool isSerial;
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

  @override
  String toString() =>
      'SchemaColumn($name, $type, nullable=$nullable, pk=$isPrimaryKey, serial=$isSerial, unique=$isUnique)';
}
