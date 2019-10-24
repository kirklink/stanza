import 'package:stanza/src/stanza_exception.dart';
import 'package:stanza/src/query.dart';
import 'package:stanza/src/field.dart';
import 'package:stanza/src/select/select_clause.dart';
import 'package:stanza/src/shared/where_clause.dart';
import 'package:stanza/src/select/group_by_clause.dart';
import 'package:stanza/src/select/order_by_clause.dart';
import 'package:stanza/src/select/limit_clause.dart';
import 'package:stanza/src/select/offset_clause.dart';
import 'package:stanza/src/table.dart';

class SelectQuery extends Query with WhereClause {

  var _selectClause = SelectClause();
  OrderByClause _orderByClause = OrderByClause();
  GroupByClause _groupByClause;
  LimitClause _limitClause;
  OffsetClause _offsetClause;

  SelectQuery(Table table) : super(table);

  String statement({bool pretty: false}) {
    var br = pretty ? '\n' : ' ';
    var select = _selectClause?.clause;
    var where = whereClauses;
    var limit = _limitClause?.clause;
    var offset = _offsetClause?.clause;
    var group = _groupByClause?.clause;
    var order = _orderByClause?.clause;
    var buf = StringBuffer();
    if (select != null) buf.writeAll(['SELECT ', select]);
    if (table != null) buf.writeAll([br, 'FROM ', table.$name]);
    if (where != null) buf.writeAll([br, where]);
    if (group != null) buf.writeAll([br, group]);
    if (order != null) buf.writeAll([br, order]);
    if (limit != null) buf.writeAll([br, limit]);
    if (offset != null) buf.writeAll([br, offset]);
    buf.write(';');
    var query = buf.toString();
    return query;
  }


  void selectFields(List<Field> fields) {
    _selectClause.add(fields);
  }

  void selectStar(Table table) {
    _selectClause.star(table);
  }

  void groupBy(List<Field> fields) {
    if (_groupByClause != null) throw StanzaException('Cannot have more than one group by clause in a query.');
    _groupByClause = GroupByClause(fields);
  }

  void orderBy(Field field, {bool descending: false}) {
    _orderByClause.add(field, descending: descending);
  }

  void limit(int i) {
    if (_limitClause != null) throw StanzaException('Cannot have more than one limit clause in a query.');
    _limitClause = LimitClause(i);
  }

  void offset(int i) {
    if (_offsetClause != null) throw StanzaException('Cannot have more than one offset clause in a query.');
    _offsetClause = OffsetClause(i);
  }

  SelectQuery fork() {
    var q = SelectQuery(table);
    q.importSubstitutionValues(substitutionValues);
    q._selectClause = _selectClause.clone();
    q._orderByClause = _orderByClause.clone();
    q._groupByClause = _groupByClause?.clone();
    q._limitClause = _limitClause?.clone();
    q._offsetClause = _offsetClause?.clone();
    return q;
  }

}