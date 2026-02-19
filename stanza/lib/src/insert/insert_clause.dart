import 'package:stanza/src/query.dart';
import 'package:stanza/src/value_substitution.dart';
import 'package:stanza/src/query_clause.dart';

/// Stores and produces the COLUMNS and VALUES clauses of an insert query.
class InsertClause implements QueryClause {
  List<String> _columns = [];
  List<List<String>> _valueTuples = [];

  /// Whether this clause contains batch (multi-row) values.
  bool get isBatch => _valueTuples.length > 1;

  /// Returns the COLUMNS and VALUES parts of an insert query.
  @override
  String get clause {
    final c = '(${_columns.join(', ')})';
    final tuples =
        _valueTuples.map((row) => '(${row.join(', ')})').join(', ');
    return '$c VALUES $tuples';
  }

  /// Insert the 'value' into the provided 'field' and pass the query through
  /// to complete the query chaining.
  void insert(String field, dynamic value, Query q) {
    final sub = ValueSub(field, value);
    q.addSubstitution(sub);
    _columns.add(field);
    if (_valueTuples.isEmpty) _valueTuples.add([]);
    _valueTuples[0].add(sub.token);
  }

  /// Add a complete row of values for batch insert.
  ///
  /// The first call sets the column list from the map keys.
  /// Subsequent calls must have the same columns (enforced by using
  /// the same [Table.toDb] method).
  void addRow(Map<String, dynamic> map, Query q) {
    if (_columns.isEmpty) {
      _columns = map.keys.toList();
    }
    final row = <String>[];
    for (final key in _columns) {
      final sub = ValueSub(key, map[key]);
      q.addSubstitution(sub);
      row.add(sub.token);
    }
    _valueTuples.add(row);
  }

  /// Clone the insert part of a query to be used in a query fork.
  @override
  InsertClause clone() {
    final x = InsertClause();
    x._columns = List.from(_columns);
    x._valueTuples =
        _valueTuples.map((row) => List<String>.from(row)).toList();
    return x;
  }
}
