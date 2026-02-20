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
