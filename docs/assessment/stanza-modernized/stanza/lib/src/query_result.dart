import 'package:stanza/src/table.dart';

/// An individual row from a database which includes a [value] that has the properties
/// of the class being queried and an [aggregate] which has any calculated results from
/// the database (SUM, COUNT, etc.)
class Result<T> {
  final T? value;
  final Map<String, dynamic> aggregate;

  Result(this.value, this.aggregate);

  @override
  String toString() {
    return '$value\nWith aggregates:\n$aggregate\n';
  }
}

/// A list of rows from the database that contains the results of a query.
class QueryResult<T> {
  /// The raw output of the query results as flat column maps.
  final List<Map<String, dynamic>> raw;
  final Table _table;

  List<Result<T>>? _cachedList;

  QueryResult(this.raw, this._table);

  /// True if the [QueryResult] contains no rows.
  bool get isEmpty => raw.isEmpty;

  /// True if the [QueryResult] contains rows.
  bool get isNotEmpty => raw.isNotEmpty;

  /// The number of rows in the result.
  int get length => raw.length;

  /// The list of all [Result]s from a query.
  List<Result<T>> get all {
    final cached = _cachedList;
    if (cached != null) return cached;

    final list = <Result<T>>[];
    for (final row in raw) {
      T? result;
      try {
        result = _table.fromDb(row) as T;
      } catch (_) {
        // If fromDb fails (e.g. partial select with missing columns),
        // the entity value will be null.
        result = null;
      }
      final container = Result<T>(result, row);
      list.add(container);
    }
    _cachedList = list;
    return list;
  }

  /// The first [Result] from a query, or null if empty.
  Result<T>? get first {
    final results = all;
    if (results.isEmpty) return null;
    return results[0];
  }

  /// A list of results that contains only the original class properties from the result row.
  List<T> get entities {
    return [for (final item in all) if (item.value != null) item.value as T];
  }

  /// A list of results that contains only the column maps from the result rows.
  List<Map<String, dynamic>> get aggregates {
    return [for (final item in all) item.aggregate];
  }
}
