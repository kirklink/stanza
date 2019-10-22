import 'package:stanza/src/table.dart';

class Result<T> {
  final T value;
  final Map<String, dynamic> aggregate;

  Result(this.value, this.aggregate);

  String toString() {
    return '$value\nWith aggregates:\n$aggregate\n';
  }
}

class QueryResult<T> {
  final List<Map<String, Map<String, dynamic>>> raw;
  Table _table;

  List<Result<T>> _cachedList;

  QueryResult(this.raw, this._table);


  bool get isEmpty => raw.isEmpty;
  bool get isNotEmpty => raw.isNotEmpty;

  List<Result<T>> all() {
    var list = List<Result<T>>();
    if (_cachedList != null) return _cachedList;
    T result;
    for (var row in raw) {
      var value = row[_table.$name];
      result = _table.fromDb(value);
      
      var aggregates = row[null];
      var container = Result<T>(result, aggregates);
      list.add(container);
    }
    if (_cachedList == null) _cachedList = list;
    return _cachedList;
  }

  Result<T> first() {
    var all = this.all();
    if (all.length == 0) return null;
    return this.all()[0];
  }

  List<T> entitiesOnly() {
    var results = List<T>();
    for (var item in this.all()) {
      results.add(item.value);
    }
    return results;
  }

  List<Map<String, dynamic>> aggregatesOnly() {
    var results = List<Map<String, dynamic>>();
    for (var item in this.all()) {
      results.add(item.aggregate);
    }
    return results;
  }






}
