/// The kind of database constraint.
enum ConstraintKind { primaryKey, unique, foreignKey }

/// Represents a database constraint (primary key, unique, or foreign key).
class SchemaConstraint {
  /// The constraint name (e.g. `'users_pkey'`, `'users_email_key'`).
  final String name;

  /// The type of constraint.
  final ConstraintKind kind;

  /// The columns involved in this constraint.
  final List<String> columns;

  /// The referenced table (foreign key only).
  final String? referencedTable;

  /// The referenced column (foreign key only).
  final String? referencedColumn;

  /// The ON DELETE action (e.g. `'CASCADE'`, `'SET NULL'`).
  final String? onDelete;

  const SchemaConstraint({
    required this.name,
    required this.kind,
    required this.columns,
    this.referencedTable,
    this.referencedColumn,
    this.onDelete,
  });
}
