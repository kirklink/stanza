import 'package:stanza/src/query_clause.dart';
import 'package:stanza/src/field.dart';

class GroupByClause implements QueryClause {
  List<String> _fields;

  GroupByClause(List<Field> fields) {
    _fields = fields.map((f) => f.qualifiedName).toList();
  }

  String get clause => "GROUP BY ${_fields.join(', ')}";

  GroupByClause clone() {
    return this;
  }
}
