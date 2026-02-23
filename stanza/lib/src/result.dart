import 'table.dart';

/// The result of a query execution, with optional entity mapping.
///
/// For SELECT queries, use [entities] to get mapped Dart objects.
/// For INSERT/UPDATE/DELETE with RETURNING, same applies.
/// For write queries without RETURNING, use [affectedRows].
class QueryResult<T> {
  /// The raw rows returned by the database.
  final List<Map<String, dynamic>> rows;

  /// The table descriptor used for mapping (null for raw queries).
  final TableDescriptor<T>? _table;

  /// Number of rows affected (for INSERT/UPDATE/DELETE without RETURNING).
  final int affectedRows;

  List<T>? _cachedEntities;

  /// Creates a query result with the given [rows] and optional [table]
  /// descriptor for entity mapping.
  QueryResult({
    required this.rows,
    TableDescriptor<T>? table,
    this.affectedRows = 0,
  }) : _table = table;

  /// Maps all rows to entity instances using the table descriptor.
  ///
  /// Results are lazily cached on first access.
  List<T> get entities {
    if (_cachedEntities != null) return _cachedEntities!;
    if (_table == null) {
      throw StateError('No table descriptor provided for entity mapping');
    }
    _cachedEntities = rows.map((row) => _table.fromRow(row)).toList();
    return _cachedEntities!;
  }

  /// The first mapped entity, or null if no rows.
  T? get firstOrNull => rows.isEmpty ? null : entities.first;

  /// Whether the result set is empty.
  bool get isEmpty => rows.isEmpty;

  /// Whether the result set has rows.
  bool get isNotEmpty => rows.isNotEmpty;

  /// Number of rows returned.
  int get length => rows.length;
}
