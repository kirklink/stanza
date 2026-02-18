import 'package:stanza/src/query.dart';
import 'package:stanza/src/field.dart';
import 'package:stanza/src/shared/where_clause.dart';
import 'package:stanza/src/update/set_clause.dart';

/// Base class for an update query.
///
/// Takes the generated code table from a [StanzaEntity].
class UpdateQuery extends Query with WhereClause {
  SetClause _setClause = SetClause();

  UpdateQuery(super.table);

  @override
  String statement({bool pretty = false}) {
    final br = pretty ? '\n' : ' ';
    final tableName = table.$name;
    final where = whereClauses;
    final sett = _setClause.clause;

    final buf = StringBuffer();
    buf.writeAll(['UPDATE ', tableName, br, 'SET ', sett]);
    if (where != null) buf.writeAll([br, where]);
    return buf.toString();
  }

  /// Target a field (database column) to have a value updated.
  SetValue column(Field field) {
    return _setClause.column(field, this);
  }

  @override
  UpdateQuery fork() {
    final q = UpdateQuery(table);
    q.importSubstitutionValues(substitutionValues);
    q._setClause = _setClause.clone();
    q.importWhereClauses(cloner());
    return q;
  }
}
