import 'package:stanza/src/query_clause.dart';
import 'package:stanza/src/field.dart';

class OrderByClause implements QueryClause {
  final List<String> _clauses = [];

  void add(Field field, {bool descending = false}) {
    final direction = descending ? ' DESC' : ' ASC';
    _clauses.add(field.sql + direction);
  }

  /// Add a raw SQL expression to the ORDER BY list.
  ///
  /// Used for ordering by computed expressions like `ts_rank(...)` or
  /// `similarity(...)` that cannot be expressed as a simple [Field].
  void addExpression(String expression, {bool descending = false}) {
    final direction = descending ? ' DESC' : ' ASC';
    _clauses.add(expression + direction);
  }

  @override
  String get clause {
    if (_clauses.isEmpty) return '';
    return 'ORDER BY ${_clauses.join(', ')}';
  }

  bool get isEmpty => _clauses.isEmpty;

  @override
  OrderByClause clone() {
    final c = OrderByClause();
    c._clauses.addAll(_clauses);
    return c;
  }
}
