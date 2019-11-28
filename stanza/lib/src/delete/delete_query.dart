import 'package:stanza/src/query.dart';
import 'package:stanza/src/table.dart';
import 'package:stanza/src/shared/where_clause.dart';

/// Base class for an insert query.
/// 
/// Takes the generated code table from a [StanzaEntity].
class DeleteQuery extends Query with WhereClause {

  DeleteQuery(Table table) : super(table);

  @override
  String statement({bool pretty: false}) {
    var br = pretty ? '\n' : ' ';
    var tableName = table?.$name ?? '';
    var where = whereClauses ?? '';
    var query = "DELETE FROM $tableName${br}$where;";
    return query;
  }


  DeleteQuery fork() {
    var q = DeleteQuery(table);
    q.importWhereClauses(this.cloner());
    return q;

  }


}