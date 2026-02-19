import 'schema/schema_table.dart';

/// The class on which generated tables are based.
abstract class Table<T> {
  String get $name;
  Type get $type;
  T fromDb(Map<String, dynamic> map);
  Map<String, dynamic> toDb(T instance);

  /// Returns the schema definition for this table, if generated.
  ///
  /// Overridden by generated table classes when schema annotations
  /// are present. Returns `null` for tables without schema metadata.
  SchemaTable? get $schema => null;
}
