import 'identifier.dart';
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
  /// The qualified column name (e.g. `'users.email'`).
  final String column;

  /// The SQL operator (e.g. `'='`, `'>'`, `'<'`).
  final String op;

  /// The value to compare against.
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
  /// The left-hand expression.
  final Expression left;

  /// The right-hand expression.
  final Expression right;

  const And(this.left, this.right);

  @override
  String toSql(ParameterCollector params) =>
      '(${left.toSql(params)} AND ${right.toSql(params)})';
}

/// Logical OR of two expressions: `(left OR right)`.
class Or extends Expression {
  /// The left-hand expression.
  final Expression left;

  /// The right-hand expression.
  final Expression right;

  const Or(this.left, this.right);

  @override
  String toSql(ParameterCollector params) =>
      '(${left.toSql(params)} OR ${right.toSql(params)})';
}

/// Logical NOT: `NOT (inner)`.
class Not extends Expression {
  /// The expression to negate.
  final Expression inner;

  const Not(this.inner);

  @override
  String toSql(ParameterCollector params) =>
      'NOT (${inner.toSql(params)})';
}

/// Membership test: `column IN (@p0, @p1, ...)`.
class InList extends Expression {
  /// The qualified column name.
  final String column;

  /// The list of values to test membership against.
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
  /// The qualified column name.
  final String column;

  /// The list of values to test exclusion against.
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
  /// The qualified column name.
  final String column;

  const IsNull(this.column);

  @override
  String toSql(ParameterCollector params) => '$column IS NULL';
}

/// Not-null check: `column IS NOT NULL`.
class IsNotNull extends Expression {
  /// The qualified column name.
  final String column;

  const IsNotNull(this.column);

  @override
  String toSql(ParameterCollector params) => '$column IS NOT NULL';
}

/// Range test: `column BETWEEN @low AND @high`.
class Between extends Expression {
  /// The qualified column name.
  final String column;

  /// The lower bound of the range (inclusive).
  final Object? low;

  /// The upper bound of the range (inclusive).
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
  /// The qualified column name.
  final String column;

  /// The LIKE pattern (e.g. `'%@example.com'`).
  final String pattern;

  /// Whether to use case-sensitive `LIKE` (true) or `ILIKE` (false).
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
  /// The qualified left-hand column name.
  final String leftColumn;

  /// The SQL operator (e.g. `'='`).
  final String op;

  /// The qualified right-hand column name.
  final String rightColumn;

  const ColumnComparison(this.leftColumn, this.op, this.rightColumn);

  @override
  String toSql(ParameterCollector params) => '$leftColumn $op $rightColumn';
}

/// Full-text search match: `to_tsvector(config, col) @@ tsquery_fn(config, @param)`.
class FullTextMatch extends Expression {
  /// The qualified column name containing searchable text.
  final String column;

  /// The search query text.
  final String query;

  /// The PostgreSQL text search configuration (e.g. `'english'`).
  final String config;

  /// The tsquery function name (e.g. `'plainto_tsquery'`).
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
///
/// Requires the `pg_trgm` PostgreSQL extension.
class TrigramSimilar extends Expression {
  /// The qualified column name.
  final String column;

  /// The text to compare for similarity.
  final String text;

  const TrigramSimilar(this.column, this.text);

  @override
  String toSql(ParameterCollector params) {
    final placeholder = params.add(text);
    return '$column % $placeholder';
  }
}

/// Word-level trigram similarity: `@param %> column`.
///
/// Requires the `pg_trgm` PostgreSQL extension.
class TrigramWordSimilar extends Expression {
  /// The qualified column name.
  final String column;

  /// The text to compare for word-level similarity.
  final String text;

  const TrigramWordSimilar(this.column, this.text);

  @override
  String toSql(ParameterCollector params) {
    final placeholder = params.add(text);
    return '$placeholder %> $column';
  }
}

/// SQLite FTS5 MATCH: `fts_table MATCH @param`.
///
/// Used in WHERE clauses to filter rows matching an FTS5 query.
/// Typically paired with a JOIN to the FTS5 virtual table via
/// [SelectQuery.fts5Join].
class Fts5Match extends Expression {
  /// The FTS5 virtual table name (e.g. `'posts_fts'`).
  final String ftsTableName;

  /// The FTS5 query string (e.g. `'database optimization'`).
  final String query;

  Fts5Match(this.ftsTableName, this.query) {
    assertValidIdentifier(ftsTableName, 'ftsTableName');
  }

  @override
  String toSql(ParameterCollector params) {
    final placeholder = params.add(query);
    return '$ftsTableName MATCH $placeholder';
  }
}

/// Subquery membership: `column IN (SELECT ...)`.
///
/// The subquery shares the same [ParameterCollector] as the outer query,
/// so all parameters are correctly numbered.
class SubqueryIn extends Expression {
  /// The qualified column name.
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
///
/// The subquery shares the same [ParameterCollector] as the outer query,
/// so all parameters are correctly numbered.
class SubqueryNotIn extends Expression {
  /// The qualified column name.
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
  /// The aggregate function (e.g. `COUNT(users.id)`).
  final AggregateExpression aggregate;

  /// The SQL comparison operator (e.g. `'>'`, `'='`).
  final String op;

  /// The value to compare the aggregate result against.
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
  /// The aggregate function.
  final AggregateExpression aggregate;

  /// The lower bound (inclusive).
  final num low;

  /// The upper bound (inclusive).
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
///
/// Named placeholders in [sql] (e.g. `:key`) are replaced with
/// generated `@pN` parameters using values from [paramValues].
class Raw extends Expression {
  /// The SQL template, optionally containing `:name` placeholders.
  final String sql;

  /// Named values to substitute for placeholders in [sql].
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
  /// The SQL function name (e.g. `'COUNT'`, `'SUM'`, `'AVG'`).
  final String function;

  /// The qualified column reference (e.g. `'users.id'`) or `'*'` for COUNT(*).
  final String columnSql;

  /// Optional alias for the SELECT list (e.g. `'post_count'`).
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

  /// Aggregate greater than: `COUNT(col) > @value`.
  Expression greaterThan(num value) =>
      AggregateComparison(this, '>', value);

  /// Aggregate greater than or equal: `COUNT(col) >= @value`.
  Expression greaterThanOrEqual(num value) =>
      AggregateComparison(this, '>=', value);

  /// Aggregate less than: `COUNT(col) < @value`.
  Expression lessThan(num value) =>
      AggregateComparison(this, '<', value);

  /// Aggregate less than or equal: `COUNT(col) <= @value`.
  Expression lessThanOrEqual(num value) =>
      AggregateComparison(this, '<=', value);

  /// Aggregate equality: `COUNT(col) = @value`.
  Expression equals(num value) =>
      AggregateComparison(this, '=', value);

  /// Aggregate inequality: `COUNT(col) != @value`.
  Expression notEquals(num value) =>
      AggregateComparison(this, '!=', value);

  /// Aggregate range: `COUNT(col) BETWEEN @low AND @high`.
  Expression between(num low, num high) =>
      AggregateBetween(this, low, high);
}

/// `COUNT(*)` — counts all rows regardless of column values.
class CountAll extends AggregateExpression {
  const CountAll({String? alias}) : super('COUNT', '*', alias: alias);
}
