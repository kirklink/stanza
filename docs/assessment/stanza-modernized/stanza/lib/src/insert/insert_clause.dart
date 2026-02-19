import 'package:stanza/src/query.dart';
import 'package:stanza/src/value_substitution.dart';
import 'package:stanza/src/query_clause.dart';

/// Stores and produces the COLUMNS and VALUES clauses of an insert query.
class InsertClause implements QueryClause {
  List<String> _columns = [];
  List<String> _values = [];

  /// Returns the COLUMNS and VALUES parts of an insert query.
  @override
  String get clause {
    final c = '(${_columns.join(', ')})';
    final v = '(${_values.join(', ')})';
    return '$c VALUES $v';
  }

  /// Insert the 'value' into the provided 'field' and pass the query through
  /// to complete the query chaining.
  void insert(String field, dynamic value, Query q) {
    final sub = ValueSub(field, value);
    q.addSubstitution(sub);
    _columns.add(field);
    _values.add(sub.token);
  }

  /// Clone the insert part of a query to be used in a query fork.
  @override
  InsertClause clone() {
    final x = InsertClause();
    x._columns = List.from(_columns);
    x._values = List.from(_values);
    return x;
  }
}
