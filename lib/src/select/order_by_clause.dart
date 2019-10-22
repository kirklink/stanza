import 'package:stanza/src/query_clause.dart';
import 'package:stanza/src/field.dart';


class OrderByClause implements QueryClause {
  
  List<String> _clauses = [];

  void add(Field field, {bool descending: false}) {
    var direction = descending ? ' DESC' : ' ASC';
    _clauses.add(field.sql + direction);
  }

  String get clause {
    if (_clauses.length == 0) return null;
    return "ORDER BY ${_clauses.join(', ')}";
  }

  OrderByClause clone() {
    return this;
  }

}