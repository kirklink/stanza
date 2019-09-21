import 'package:stanza/src/query.dart';
import 'package:stanza/src/field.dart';
import 'package:stanza/src/shared/where_clause.dart';
import 'package:stanza/src/update/set_clause.dart';
import 'package:stanza/src/table.dart';

class UpdateQuery extends Query with WhereClause {

  var _setClause = SetClause();

  UpdateQuery(Table table) : super(table);

  @override
  String statement({bool pretty: false}) {
    var br = pretty ? '\n' : ' ';
    var table = tableName ?? '';
    var where = whereClauses ?? '';
    var sett = _setClause.clause ?? '';
    var sbr = br;
    var wbr = br;
    if (pretty) {
      if (where == '') wbr = '';
    }
    var query = "UPDATE $table${sbr}SET $sett$wbr$where;";
    return query;
  }


  SetValue column(Field field) {
    return _setClause.column(field, this);
  }

  UpdateQuery fork() {
    var q = UpdateQuery(table);
    q.importSubstitutionValues(substitutionValues);
    q._setClause = _setClause.clone();
    q.importWhereClauses(this.cloner());
    return q;
  }

}