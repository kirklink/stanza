/// The kind of database constraint.
enum ConstraintKind { primaryKey, unique, foreignKey }

/// Represents a database constraint (PK, UNIQUE, or FK).
class SchemaConstraint {
  final String name;
  final ConstraintKind kind;
  final List<String> columns;
  final String? referencedTable;
  final String? referencedColumn;
  final String? onDelete;

  const SchemaConstraint({
    required this.name,
    required this.kind,
    required this.columns,
    this.referencedTable,
    this.referencedColumn,
    this.onDelete,
  });

  @override
  String toString() =>
      'SchemaConstraint($name, $kind, columns=$columns)';
}
