import 'package:stanza/src/table.dart';

/// An individual row from a database which includes a [value] that has the properies
/// of the class being queried and an [aggregate] which has any calculated results from
/// the database (SUM, COUNT, etc.)
class Result<T> {
  final T value;
  final Map<String, dynamic> aggregate;

  Result(this.value, this.aggregate);

  String toString() {
    return '$value\nWith aggregates:\n$aggregate\n';
  }
}

/// A list of rows from the database that contains the results of a query.
class QueryResult<T> {
  /// The raw output of the query results.
  final List<Map<String, Map<String, dynamic>>> raw;
  Table _table;

  List<Result<T>> _cachedList;

  QueryResult(this.raw, this._table);

  /// True if the [QueryResult] contains no rows.
  bool get isEmpty => raw.isEmpty;
  /// True if the [QueryResult] contains rows.
  bool get isNotEmpty => raw.isNotEmpty;

  /// The list of all [Result]s from a query.
  List<Result<T>> get all {
    var list = List<Result<T>>();
    if (_cachedList != null) return _cachedList;
    T result;
    for (var row in raw) {
      var value = row[_table.$name];

      if (value != null) {
        result = _table.fromDb(value);
      }
      
      var aggregates = row[null];
      var container = Result<T>(result, aggregates);
      list.add(container);
    }
    if (_cachedList == null) _cachedList = list;
    return _cachedList;
  }

  /// The first [Result] from a query.
  Result<T> get first {
    var all = this.all;
    if (all.length == 0) return null;
    return this.all[0];
  }

  /// A list of results that contains only the original class properties from the result row (aggregates are not available).
  List<T> get entities {
    var results = List<T>();
    for (var item in this.all) {
      results.add(item.value);
    }
    return results;
  }

  /// A list of results that contains only the aggregates from the result rows.
  List<Map<String, dynamic>> get aggregates {
    var results = List<Map<String, dynamic>>();
    for (var item in this.all) {
      results.add(item.aggregate);
    }
    return results;
  }






}
