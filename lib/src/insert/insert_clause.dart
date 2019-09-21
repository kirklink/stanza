import 'package:stanza/src/query.dart';
import 'package:stanza/src/value_substitution.dart';
import 'package:stanza/src/query_clause.dart';



class InsertClause implements QueryClause {

  var _columns = List<String>();
  var _values = List<String>();


  String get clause {
    String c = "(${_columns.join(', ')})";
    String v = "(${_values.join(', ')})";
    return "$c VALUES $v";
  
  }

  void insert(String field, dynamic value, Query q) {
    var sub = ValueSub(field, value);
    q.addSubstitution(sub);
    _columns.add(field);
    _values.add(sub.token);
  }

  InsertClause clone() {
    var x = InsertClause();
    x._columns = List.from(_columns);
    x._values = List.from(_values);
    return x;
  }

}