import 'package:stanza/src/query.dart';
import 'package:stanza/src/table.dart';
import 'package:stanza/src/field.dart';
import 'package:stanza/src/shared/where_clause.dart';
import 'package:stanza/src/update/set_clause.dart';

/// Base class for an insert query.
///
/// Takes the generated code table from a [StanzaEntity].
class UpdateQuery extends Query with WhereClause {
  var _setClause = SetClause();

  UpdateQuery(Table table) : super(table);

  @override
  String statement({bool pretty = false}) {
    var br = pretty ? '\n' : ' ';
    var tableName = table?.$name ?? '';
    var where = whereClauses ?? '';
    var sett = _setClause.clause ?? '';
    var sbr = br;
    var wbr = br;
    if (pretty) {
      if (where == '') wbr = '';
    }
    var query = "UPDATE $tableName${sbr}SET $sett$wbr$where;";
    return query;
  }

  /// Target a field (database column) to have a value updated.
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
