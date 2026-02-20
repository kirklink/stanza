import 'parameter.dart';

/// A composable SQL expression that renders to parameterized SQL.
///
/// Expressions are produced by typed column methods (e.g. `t.email.equals('foo')`)
/// and combined with `&` (AND) and `|` (OR).
sealed class Expression {
  const Expression();

  /// Renders this expression to a SQL string, registering values in [params].
  String toSql(ParameterCollector params);

  /// Combines this expression with [other] using AND.
  Expression operator &(Expression other) => And(this, other);

  /// Combines this expression with [other] using OR.
  Expression operator |(Expression other) => Or(this, other);
}

/// A simple comparison: `column op @param`.
class Comparison extends Expression {
  final String column;
  final String op;
  final Object? value;

  const Comparison(this.column, this.op, this.value);

  @override
  String toSql(ParameterCollector params) {
    final placeholder = params.add(value);
    return '$column $op $placeholder';
  }
}

/// Logical AND of two expressions: `(left AND right)`.
class And extends Expression {
  final Expression left;
  final Expression right;

  const And(this.left, this.right);

  @override
  String toSql(ParameterCollector params) =>
      '(${left.toSql(params)} AND ${right.toSql(params)})';
}

/// Logical OR of two expressions: `(left OR right)`.
class Or extends Expression {
  final Expression left;
  final Expression right;

  const Or(this.left, this.right);

  @override
  String toSql(ParameterCollector params) =>
      '(${left.toSql(params)} OR ${right.toSql(params)})';
}

/// Logical NOT: `NOT (inner)`.
class Not extends Expression {
  final Expression inner;

  const Not(this.inner);

  @override
  String toSql(ParameterCollector params) =>
      'NOT (${inner.toSql(params)})';
}

/// Membership test: `column IN (@p0, @p1, ...)`.
class InList extends Expression {
  final String column;
  final List<Object?> values;

  const InList(this.column, this.values);

  @override
  String toSql(ParameterCollector params) {
    final placeholders = values.map((v) => params.add(v)).join(', ');
    return '$column IN ($placeholders)';
  }
}

/// Negative membership test: `column NOT IN (@p0, @p1, ...)`.
class NotInList extends Expression {
  final String column;
  final List<Object?> values;

  const NotInList(this.column, this.values);

  @override
  String toSql(ParameterCollector params) {
    final placeholders = values.map((v) => params.add(v)).join(', ');
    return '$column NOT IN ($placeholders)';
  }
}

/// Null check: `column IS NULL`.
class IsNull extends Expression {
  final String column;

  const IsNull(this.column);

  @override
  String toSql(ParameterCollector params) => '$column IS NULL';
}

/// Not-null check: `column IS NOT NULL`.
class IsNotNull extends Expression {
  final String column;

  const IsNotNull(this.column);

  @override
  String toSql(ParameterCollector params) => '$column IS NOT NULL';
}

/// Range test: `column BETWEEN @low AND @high`.
class Between extends Expression {
  final String column;
  final Object? low;
  final Object? high;

  const Between(this.column, this.low, this.high);

  @override
  String toSql(ParameterCollector params) {
    final lowP = params.add(low);
    final highP = params.add(high);
    return '$column BETWEEN $lowP AND $highP';
  }
}

/// Pattern match: `column LIKE @pattern` or `column ILIKE @pattern`.
class Like extends Expression {
  final String column;
  final String pattern;
  final bool caseSensitive;

  const Like(this.column, this.pattern, {this.caseSensitive = true});

  @override
  String toSql(ParameterCollector params) {
    final placeholder = params.add(pattern);
    final op = caseSensitive ? 'LIKE' : 'ILIKE';
    return '$column $op $placeholder';
  }
}

/// Column-to-column comparison: `left_col op right_col` (no parameters).
///
/// Used for JOIN conditions where both sides are columns.
class ColumnComparison extends Expression {
  final String leftColumn;
  final String op;
  final String rightColumn;

  const ColumnComparison(this.leftColumn, this.op, this.rightColumn);

  @override
  String toSql(ParameterCollector params) => '$leftColumn $op $rightColumn';
}

/// Full-text search match: `to_tsvector(config, col) @@ tsquery_fn(config, @param)`.
class FullTextMatch extends Expression {
  final String column;
  final String query;
  final String config;
  final String queryFunction;

  const FullTextMatch(
    this.column,
    this.query, {
    required this.config,
    required this.queryFunction,
  });

  @override
  String toSql(ParameterCollector params) {
    final placeholder = params.add(query);
    return "to_tsvector('$config', $column) @@ $queryFunction('$config', $placeholder)";
  }
}

/// Trigram similarity: `column % @param`.
class TrigramSimilar extends Expression {
  final String column;
  final String text;

  const TrigramSimilar(this.column, this.text);

  @override
  String toSql(ParameterCollector params) {
    final placeholder = params.add(text);
    return '$column % $placeholder';
  }
}

/// Word-level trigram similarity: `@param %> column`.
class TrigramWordSimilar extends Expression {
  final String column;
  final String text;

  const TrigramWordSimilar(this.column, this.text);

  @override
  String toSql(ParameterCollector params) {
    final placeholder = params.add(text);
    return '$placeholder %> $column';
  }
}

/// Subquery membership: `column IN (SELECT ...)`.
///
/// The subquery shares the same [ParameterCollector] as the outer query,
/// so all parameters are correctly numbered.
class SubqueryIn extends Expression {
  final String column;
  final String Function(ParameterCollector) _subquerySql;

  SubqueryIn(this.column, this._subquerySql);

  @override
  String toSql(ParameterCollector params) {
    final subSql = _subquerySql(params);
    return '$column IN ($subSql)';
  }
}

/// Subquery negative membership: `column NOT IN (SELECT ...)`.
class SubqueryNotIn extends Expression {
  final String column;
  final String Function(ParameterCollector) _subquerySql;

  SubqueryNotIn(this.column, this._subquerySql);

  @override
  String toSql(ParameterCollector params) {
    final subSql = _subquerySql(params);
    return '$column NOT IN ($subSql)';
  }
}

/// Comparison of an aggregate function result: `COUNT(col) > @param`.
///
/// Used in HAVING clauses.
class AggregateComparison extends Expression {
  final AggregateExpression aggregate;
  final String op;
  final Object value;

  const AggregateComparison(this.aggregate, this.op, this.value);

  @override
  String toSql(ParameterCollector params) {
    final placeholder = params.add(value);
    return '${aggregate.toSql()} $op $placeholder';
  }
}

/// Range test on an aggregate: `COUNT(col) BETWEEN @low AND @high`.
class AggregateBetween extends Expression {
  final AggregateExpression aggregate;
  final num low;
  final num high;

  const AggregateBetween(this.aggregate, this.low, this.high);

  @override
  String toSql(ParameterCollector params) {
    final lowP = params.add(low);
    final highP = params.add(high);
    return '${aggregate.toSql()} BETWEEN $lowP AND $highP';
  }
}

/// Raw SQL expression with optional parameter values.
class Raw extends Expression {
  final String sql;
  final Map<String, Object?>? paramValues;

  const Raw(this.sql, {this.paramValues});

  @override
  String toSql(ParameterCollector params) {
    if (paramValues != null) {
      var result = sql;
      for (final entry in paramValues!.entries) {
        final placeholder = params.add(entry.value);
        result = result.replaceAll(':${entry.key}', placeholder);
      }
      return result;
    }
    return sql;
  }
}

// ---------------------------------------------------------------------------
// Aggregate expressions (standalone, not sealed subtypes of Expression)
// ---------------------------------------------------------------------------

/// An aggregate function expression: `COUNT(col)`, `SUM(col)`, etc.
///
/// Not a subtype of [Expression]. Use comparison methods (`greaterThan`,
/// `equals`, etc.) to produce [Expression] objects for HAVING clauses.
///
/// ```dart
/// // In a select
/// query.selectExpression(posts.id.count().as('post_count'));
///
/// // In a HAVING clause
/// query.having((t) => t.id.count().greaterThan(5));
/// ```
class AggregateExpression {
  final String function;
  final String columnSql;
  final String? alias;

  const AggregateExpression(this.function, this.columnSql, {this.alias});

  /// Renders the function call: `COUNT(users.id)`.
  String toSql() => '$function($columnSql)';

  /// Renders for SELECT with optional alias: `COUNT(users.id) AS count`.
  String toSelectSql() =>
      alias != null ? '$function($columnSql) AS $alias' : toSql();

  /// Returns a new aggregate with an alias for the SELECT list.
  AggregateExpression as(String name) =>
      AggregateExpression(function, columnSql, alias: name);

  // -- Comparison methods for HAVING clauses --

  Expression greaterThan(num value) =>
      AggregateComparison(this, '>', value);

  Expression greaterThanOrEqual(num value) =>
      AggregateComparison(this, '>=', value);

  Expression lessThan(num value) =>
      AggregateComparison(this, '<', value);

  Expression lessThanOrEqual(num value) =>
      AggregateComparison(this, '<=', value);

  Expression equals(num value) =>
      AggregateComparison(this, '=', value);

  Expression notEquals(num value) =>
      AggregateComparison(this, '!=', value);

  Expression between(num low, num high) =>
      AggregateBetween(this, low, high);
}

/// `COUNT(*)` — counts all rows regardless of column values.
class CountAll extends AggregateExpression {
  const CountAll({String? alias}) : super('COUNT', '*', alias: alias);
}
