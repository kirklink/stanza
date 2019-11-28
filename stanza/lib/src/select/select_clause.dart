import 'package:stanza/src/query_clause.dart';
import 'package:stanza/src/field.dart';
import 'package:stanza/src/table.dart';

class SelectClause<T> implements QueryClause {
  List<String> _fields = [];

  SelectClause();

  String get clause => '${_fields.join(', ')}';

  void add(List<Field> fields) {
    for (var f in fields) {
      _fields.add(f.sql);
    }
  }

  void star(Table table) {
    _fields.add(table.$name + '.*');
  }

  SelectClause clone() {
    return this;
  }
}
