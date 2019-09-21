import 'package:stanza/src/query_clause.dart';
import 'package:stanza/src/table.dart';
import 'package:stanza/src/field.dart';


class SelectClause<T> implements QueryClause {

  List<String> _fields = [];
  
  SelectClause();

  String get clause => '${_fields.join(', ')}';

  void add(List<Field> fields) {
    _fields.addAll(fields.map((f) => f.dbNameQualified).toList());
  }

  void star(Table adapter) {
    _fields.add(adapter.dbName + '.*');
  }

  SelectClause clone() {
    return this;
  }

}