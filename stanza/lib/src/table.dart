import 'column.dart';
import 'schema/schema_table.dart';

/// Base class for generated table descriptors.
///
/// Each `@StanzaEntity` class gets a corresponding `$<Entity>Table` that extends this.
/// The table descriptor provides typed column references, row mapping, and schema metadata.
///
/// Example generated code:
/// ```dart
/// class $UserTable extends TableDescriptor<User> {
///   @override String get tableName => 'users';
///   final id = IntColumn('id', 'users');
///   final email = StringColumn('email', 'users');
///   @override List<Column> get columns => [id, email];
///   @override Column get primaryKey => id;
///   @override User fromRow(Map<String, dynamic> row) => User(id: row['id'], ...);
/// }
/// ```
abstract class TableDescriptor<T> {
  /// Creates a table descriptor.
  const TableDescriptor();

  /// The database table name (e.g. `'users'`).
  String get tableName;

  /// All columns in this table, in declaration order.
  List<Column> get columns;

  /// The primary key column.
  Column get primaryKey;

  /// Maps a database row to an entity instance.
  T fromRow(Map<String, dynamic> row);

  /// Schema metadata for migration support.
  ///
  /// Override in generated table descriptors. Returns null by default
  /// (for hand-written descriptors without schema metadata).
  SchemaTable? get $schema => null;
}
