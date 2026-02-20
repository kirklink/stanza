import 'column.dart';
import 'expression.dart';
import 'order.dart';
import 'parameter.dart';
import 'query.dart';
import 'table.dart';

/// A type-safe SELECT query builder.
///
/// ```dart
/// final query = SelectQuery(userTable)
///     .where((t) => t.email.like('%@example.com') & t.active.isTrue())
///     .orderBy((t) => t.createdAt.desc())
///     .limit(10);
/// ```
class SelectQuery<T, D extends TableDescriptor<T>> extends Query<T, D> {
  final List<Expression> _wheres = [];
  final List<OrderExpression> _orders = [];
  final List<_Join> _joins = [];
  int? _limit;
  int? _offset;
  bool _distinct = false;
  List<Column>? _selectColumns;

  SelectQuery(super.table);

  /// Adds a WHERE condition. Multiple calls are combined with AND.
  SelectQuery<T, D> where(Expression Function(D t) predicate) {
    _wheres.add(predicate(table));
    return this;
  }

  /// Adds an ORDER BY clause.
  SelectQuery<T, D> orderBy(OrderExpression Function(D t) order) {
    _orders.add(order(table));
    return this;
  }

  /// Limits the number of rows returned.
  SelectQuery<T, D> limit(int n) {
    _limit = n;
    return this;
  }

  /// Skips the first [n] rows.
  SelectQuery<T, D> offset(int n) {
    _offset = n;
    return this;
  }

  /// Makes the query SELECT DISTINCT.
  SelectQuery<T, D> distinct() {
    _distinct = true;
    return this;
  }

  /// Selects specific columns instead of `*`.
  SelectQuery<T, D> selectOnly(List<Column> Function(D t) columns) {
    _selectColumns = columns(table);
    return this;
  }

  /// Adds an INNER JOIN.
  SelectQuery<T, D> innerJoin<J, JD extends TableDescriptor<J>>(
    JD joinTable,
    Expression Function(D t, JD j) on,
  ) {
    _joins.add(_Join('INNER JOIN', joinTable.tableName, on(table, joinTable)));
    return this;
  }

  /// Adds a LEFT JOIN.
  SelectQuery<T, D> leftJoin<J, JD extends TableDescriptor<J>>(
    JD joinTable,
    Expression Function(D t, JD j) on,
  ) {
    _joins.add(_Join('LEFT JOIN', joinTable.tableName, on(table, joinTable)));
    return this;
  }

  /// Adds a RIGHT JOIN.
  SelectQuery<T, D> rightJoin<J, JD extends TableDescriptor<J>>(
    JD joinTable,
    Expression Function(D t, JD j) on,
  ) {
    _joins.add(_Join('RIGHT JOIN', joinTable.tableName, on(table, joinTable)));
    return this;
  }

  @override
  String toSql(ParameterCollector params) {
    final buf = StringBuffer();

    // SELECT
    buf.write('SELECT ');
    if (_distinct) buf.write('DISTINCT ');
    if (_selectColumns != null && _selectColumns!.isNotEmpty) {
      buf.write(_selectColumns!.map((c) => c.qualified).join(', '));
    } else {
      buf.write('${table.tableName}.*');
    }

    // FROM
    buf.write(' FROM ${table.tableName}');

    // JOINs
    for (final join in _joins) {
      buf.write(' ${join.type} ${join.tableName} ON ${join.on.toSql(params)}');
    }

    // WHERE
    if (_wheres.isNotEmpty) {
      buf.write(' WHERE ');
      if (_wheres.length == 1) {
        buf.write(_wheres.first.toSql(params));
      } else {
        // Multiple wheres are ANDed together
        final combined =
            _wheres.reduce((a, b) => And(a, b));
        buf.write(combined.toSql(params));
      }
    }

    // ORDER BY
    if (_orders.isNotEmpty) {
      buf.write(' ORDER BY ');
      buf.write(_orders.map((o) => o.toSql()).join(', '));
    }

    // LIMIT
    if (_limit != null) {
      buf.write(' LIMIT $_limit');
    }

    // OFFSET
    if (_offset != null) {
      buf.write(' OFFSET $_offset');
    }

    return buf.toString();
  }
}

class _Join {
  final String type;
  final String tableName;
  final Expression on;

  _Join(this.type, this.tableName, this.on);
}
