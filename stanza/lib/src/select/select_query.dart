import 'package:stanza/src/stanza_exception.dart';
import 'package:stanza/src/query.dart';
import 'package:stanza/src/field.dart';
import 'package:stanza/src/select/select_clause.dart';
import 'package:stanza/src/select/join_clause.dart';
import 'package:stanza/src/shared/where_clause.dart';
import 'package:stanza/src/select/having_clause.dart';
import 'package:stanza/src/select/group_by_clause.dart';
import 'package:stanza/src/select/order_by_clause.dart';
import 'package:stanza/src/select/limit_clause.dart';
import 'package:stanza/src/select/offset_clause.dart';
import 'package:stanza/src/table.dart';

/// Base class for a select query.
///
/// Takes the generated code table from a [StanzaEntity].
class SelectQuery extends Query with WhereClause, HavingClause {
  SelectClause _selectClause = SelectClause();
  List<JoinClause> _joins = [];
  OrderByClause _orderByClause = OrderByClause();
  GroupByClause? _groupByClause;
  LimitClause? _limitClause;
  OffsetClause? _offsetClause;
  bool _distinct = false;

  SelectQuery(super.table);

  @override
  String statement({bool pretty = false}) {
    final br = pretty ? '\n' : ' ';
    final select = _selectClause.clause;
    final where = whereClauses;
    final limit = _limitClause?.clause;
    final offset = _offsetClause?.clause;
    final group = _groupByClause?.clause;
    final order = _orderByClause.isEmpty ? null : _orderByClause.clause;

    final buf = StringBuffer();
    buf.writeAll(['SELECT ', if (_distinct) 'DISTINCT ', select]);
    buf.writeAll([br, 'FROM ', table.$name]);
    for (final join in _joins) {
      buf.writeAll([br, join.clause]);
    }
    final having = havingClauses;
    if (where != null) buf.writeAll([br, where]);
    if (group != null) buf.writeAll([br, group]);
    if (having != null) buf.writeAll([br, having]);
    if (order != null) buf.writeAll([br, order]);
    if (limit != null) buf.writeAll([br, limit]);
    if (offset != null) buf.writeAll([br, offset]);
    return buf.toString();
  }

  /// Mark this query as SELECT DISTINCT.
  void distinct() {
    _distinct = true;
  }

  /// Select a list of [Field]s from a [StanzaEntity] table.
  void selectFields(List<Field> fields) {
    _selectClause.add(fields);
  }

  /// Select all the [Field]s from a [StanzaEntity] table.
  void selectStar([Table? t]) {
    _selectClause.star(t ?? table);
  }

  /// Add an INNER JOIN to this query.
  JoinClause innerJoin(Table joinTable) {
    final join = JoinClause(JoinType.inner, joinTable);
    _joins.add(join);
    return join;
  }

  /// Add a LEFT JOIN to this query.
  JoinClause leftJoin(Table joinTable) {
    final join = JoinClause(JoinType.left, joinTable);
    _joins.add(join);
    return join;
  }

  /// Add a RIGHT JOIN to this query.
  JoinClause rightJoin(Table joinTable) {
    final join = JoinClause(JoinType.right, joinTable);
    _joins.add(join);
    return join;
  }

  /// Add a CROSS JOIN to this query.
  JoinClause crossJoin(Table joinTable) {
    final join = JoinClause(JoinType.cross, joinTable);
    _joins.add(join);
    return join;
  }

  /// Group a select query by a list of [Field]s.
  void groupBy(List<Field> fields) {
    if (_groupByClause != null) {
      throw StanzaException(
          'Cannot have more than one group by clause in a query.');
    }
    _groupByClause = GroupByClause(fields);
  }

  /// Order a select query by the provided [Field].
  ///
  /// [descending]: can be made true to reverse the sort order.
  /// Multiple orderBy clauses can be added to a select query and they are applied in the
  /// order provided.
  void orderBy(Field field, {bool descending = false}) {
    _orderByClause.add(field, descending: descending);
  }

  /// Limit the number of results returned by a query.
  void limit(int i) {
    if (_limitClause != null) {
      throw StanzaException(
          'Cannot have more than one limit clause in a query.');
    }
    _limitClause = LimitClause(i);
  }

  /// Offset the results returned by a query by this number of rows.
  void offset(int i) {
    if (_offsetClause != null) {
      throw StanzaException(
          'Cannot have more than one offset clause in a query.');
    }
    _offsetClause = OffsetClause(i);
  }

  /// Reproduce a partial query to use in a loop or other dynamic pattern.
  @override
  SelectQuery fork() {
    final q = SelectQuery(table);
    q.importSubstitutionValues(substitutionValues);
    q._distinct = _distinct;
    q._selectClause = _selectClause.clone();
    q._joins = _joins.map((j) => j.clone()).toList();
    q._orderByClause = _orderByClause.clone();
    q._groupByClause = _groupByClause?.clone();
    q._limitClause = _limitClause?.clone();
    q._offsetClause = _offsetClause?.clone();
    q.importWhereClauses(cloner());
    q.importHavingClauses(havingCloner());
    return q;
  }
}
