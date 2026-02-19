import 'package:stanza/src/query.dart';
import 'package:stanza/src/shared/where_clause.dart';
import 'package:stanza/src/shared/returning_clause.dart';

/// Base class for a delete query.
///
/// Takes the generated code table from a [StanzaEntity].
class DeleteQuery extends Query with WhereClause, ReturningClause {
  DeleteQuery(super.table);

  @override
  String statement({bool pretty = false}) {
    final br = pretty ? '\n' : ' ';
    final tableName = table.$name;
    final where = whereClauses;
    final ret = returningClause;

    final buf = StringBuffer('DELETE FROM $tableName');
    if (where != null) buf.writeAll([br, where]);
    if (ret != null) buf.writeAll([br, ret]);
    return buf.toString();
  }

  @override
  DeleteQuery fork() {
    final q = DeleteQuery(table);
    q.importWhereClauses(cloner());
    q.importReturningClause(this);
    return q;
  }
}
