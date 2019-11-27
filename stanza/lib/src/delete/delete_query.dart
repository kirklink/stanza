import 'package:stanza/src/stanza_exception.dart';
import 'package:stanza/src/query.dart';
import 'package:stanza/src/table.dart';
import 'package:stanza/src/field.dart';
import 'package:stanza/src/shared/where_clause.dart';


class DeleteQuery extends Query with WhereClause {

  DeleteQuery(Table table) : super(table);

  @override
  String statement({bool pretty: false}) {
    var br = pretty ? '\n' : ' ';
    var tableName = table?.$name ?? '';
    var where = whereClauses ?? '';
    var ibr = br;
    var query = "DELETE $tableName${ibr}$insert;";
    return query;
  }

  void delete(Field field, dynamic value) {
    _delete.delete(field.name, value, this);
  }


  DeleteQuery fork() {
    var q = DeleteQuery(table);
    q.importSubstitutionValues(substitutionValues);
    q._delete = _delete.clone();
    return q;

  }


}