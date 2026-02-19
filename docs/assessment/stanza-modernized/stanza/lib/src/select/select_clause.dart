import 'package:stanza/src/query_clause.dart';
import 'package:stanza/src/field.dart';
import 'package:stanza/src/table.dart';

class SelectClause implements QueryClause {
  final List<String> _fields = [];

  SelectClause();

  @override
  String get clause => _fields.join(', ');

  void add(List<Field> fields) {
    for (final f in fields) {
      _fields.add(f.sql);
    }
  }

  void star(Table table) {
    _fields.add('${table.$name}.*');
  }

  @override
  SelectClause clone() {
    final c = SelectClause();
    c._fields.addAll(_fields);
    return c;
  }
}
