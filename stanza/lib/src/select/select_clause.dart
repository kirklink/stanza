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

  /// Add a raw SQL expression to the SELECT list.
  ///
  /// Used for computed expressions like `ts_rank(...)`, `ts_headline(...)`,
  /// or `similarity(...)` that cannot be expressed as a simple [Field].
  void addExpression(String expression) {
    _fields.add(expression);
  }

  @override
  SelectClause clone() {
    final c = SelectClause();
    c._fields.addAll(_fields);
    return c;
  }
}
