import 'package:stanza/src/query.dart';
import 'package:stanza/src/table.dart';
import 'package:stanza/src/shared/where_clause.dart';

/// Base class for a delete query.
///
/// Takes the generated code table from a [StanzaEntity].
class DeleteQuery extends Query with WhereClause {
  DeleteQuery(Table table) : super(table);

  @override
  String statement({bool pretty = false}) {
    final br = pretty ? '\n' : ' ';
    final tableName = table.$name;
    final where = whereClauses ?? '';
    return 'DELETE FROM $tableName$br$where';
  }

  @override
  DeleteQuery fork() {
    final q = DeleteQuery(table);
    q.importWhereClauses(cloner());
    return q;
  }
}
