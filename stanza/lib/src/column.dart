import 'expression.dart';
import 'fts.dart';
import 'order.dart';
import 'query.dart';

/// Base class for typed column references.
///
/// Each column knows its database name and table, and provides
/// type-safe comparison methods that return [Expression] objects.
///
/// Column subclasses add type-specific operations:
/// - [IntColumn]: numeric comparisons (`greaterThan`, `between`)
/// - [StringColumn]: pattern matching (`like`, `startsWith`, `contains`)
/// - [DateTimeColumn]: temporal comparisons (`before`, `after`)
/// - [BoolColumn]: boolean checks (`isTrue`, `isFalse`)
/// - [DoubleColumn]: numeric comparisons
abstract class Column<T> {
  /// The column name in the database (e.g. `'created_at'`).
  final String name;

  /// The table name for qualified references (e.g. `'users'`).
  final String table;

  const Column(this.name, this.table);

  /// Fully qualified column name: `table.column`.
  String get qualified => '$table.$name';

  // -- Universal comparison operations --

  /// Equality: `column = @value`.
  Expression equals(T value) => Comparison(qualified, '=', value);

  /// Inequality: `column != @value`.
  Expression notEquals(T value) => Comparison(qualified, '!=', value);

  /// Null check: `column IS NULL`.
  Expression isNull() => IsNull(qualified);

  /// Not-null check: `column IS NOT NULL`.
  Expression isNotNull() => IsNotNull(qualified);

  /// Membership: `column IN (@v0, @v1, ...)`.
  Expression isIn(List<T> values) => InList(qualified, values);

  /// Negative membership: `column NOT IN (@v0, @v1, ...)`.
  Expression notIn(List<T> values) => NotInList(qualified, values);

  // -- Column-to-column comparisons (for JOINs) --

  /// Column equality: `this_col = other_col`. Used in JOIN conditions.
  Expression equalsColumn(Column<T> other) =>
      ColumnComparison(qualified, '=', other.qualified);

  // -- Subquery membership --

  /// Subquery membership: `column IN (SELECT ...)`.
  ///
  /// ```dart
  /// final activeIds = SelectQuery(users)
  ///     .selectOnly((t) => [t.id])
  ///     .where((t) => t.createdAt.after(cutoff));
  /// SelectQuery(posts).where((t) => t.authorId.isInQuery(activeIds));
  /// ```
  Expression isInQuery(Query subquery) =>
      SubqueryIn(qualified, (params) => subquery.toSql(params));

  /// Subquery negative membership: `column NOT IN (SELECT ...)`.
  Expression notInQuery(Query subquery) =>
      SubqueryNotIn(qualified, (params) => subquery.toSql(params));

  // -- Ordering --

  /// Ascending order: `column ASC`.
  OrderExpression asc() => OrderExpression(qualified);

  /// Descending order: `column DESC`.
  OrderExpression desc() => OrderExpression(qualified, descending: true);

  // -- Aggregates --

  /// `COUNT(column)` — counts non-null values.
  AggregateExpression count() => AggregateExpression('COUNT', qualified);

  /// `MIN(column)` — minimum value.
  AggregateExpression min() => AggregateExpression('MIN', qualified);

  /// `MAX(column)` — maximum value.
  AggregateExpression max() => AggregateExpression('MAX', qualified);
}

/// A column holding `int` values.
///
/// Provides numeric comparison operations in addition to the universal ones.
class IntColumn extends Column<int> {
  const IntColumn(super.name, super.table);

  Expression greaterThan(int value) => Comparison(qualified, '>', value);
  Expression greaterThanOrEqual(int value) =>
      Comparison(qualified, '>=', value);
  Expression lessThan(int value) => Comparison(qualified, '<', value);
  Expression lessThanOrEqual(int value) => Comparison(qualified, '<=', value);
  Expression between(int low, int high) => Between(qualified, low, high);

  /// `SUM(column)` — total of all values.
  AggregateExpression sum() => AggregateExpression('SUM', qualified);

  /// `AVG(column)` — average of all values.
  AggregateExpression avg() => AggregateExpression('AVG', qualified);
}

/// A column holding `double` values.
class DoubleColumn extends Column<double> {
  const DoubleColumn(super.name, super.table);

  Expression greaterThan(double value) => Comparison(qualified, '>', value);
  Expression greaterThanOrEqual(double value) =>
      Comparison(qualified, '>=', value);
  Expression lessThan(double value) => Comparison(qualified, '<', value);
  Expression lessThanOrEqual(double value) =>
      Comparison(qualified, '<=', value);
  Expression between(double low, double high) => Between(qualified, low, high);

  /// `SUM(column)` — total of all values.
  AggregateExpression sum() => AggregateExpression('SUM', qualified);

  /// `AVG(column)` — average of all values.
  AggregateExpression avg() => AggregateExpression('AVG', qualified);
}

/// A column holding `String` values.
///
/// Provides pattern matching and text search operations.
class StringColumn extends Column<String> {
  const StringColumn(super.name, super.table);

  /// Case-sensitive pattern match: `column LIKE @pattern`.
  Expression like(String pattern) =>
      Like(qualified, pattern, caseSensitive: true);

  /// Case-insensitive pattern match: `column ILIKE @pattern`.
  Expression ilike(String pattern) =>
      Like(qualified, pattern, caseSensitive: false);

  /// Starts with prefix: `column LIKE '@prefix%'`.
  Expression startsWith(String prefix) =>
      Like(qualified, '$prefix%', caseSensitive: true);

  /// Ends with suffix: `column LIKE '%@suffix'`.
  Expression endsWith(String suffix) =>
      Like(qualified, '%$suffix', caseSensitive: true);

  /// Contains substring: `column LIKE '%@substring%'`.
  Expression contains(String substring) =>
      Like(qualified, '%$substring%', caseSensitive: true);

  // -- Full-text search --

  /// Full-text search match using `to_tsvector @@ tsquery`.
  ///
  /// ```dart
  /// query.where((t) => t.body.fullTextMatches('database optimization'));
  /// ```
  Expression fullTextMatches(
    String query, {
    FtsConfig config = FtsConfig.english,
    FtsQueryType queryType = FtsQueryType.plain,
  }) =>
      FullTextMatch(
        qualified,
        query,
        config: config.value,
        queryFunction: queryType.functionName,
      );

  // -- Trigram similarity --

  /// Trigram similarity: `column % @text`.
  ///
  /// Requires the `pg_trgm` extension.
  Expression isSimilarTo(String text) => TrigramSimilar(qualified, text);

  /// Word-level trigram similarity: `@text %> column`.
  ///
  /// Requires the `pg_trgm` extension.
  Expression isWordSimilarTo(String text) =>
      TrigramWordSimilar(qualified, text);
}

/// A column holding `bool` values.
class BoolColumn extends Column<bool> {
  const BoolColumn(super.name, super.table);

  /// Check for true: `column = true`.
  Expression isTrue() => Comparison(qualified, '=', true);

  /// Check for false: `column = false`.
  Expression isFalse() => Comparison(qualified, '=', false);
}

/// A column holding `DateTime` values.
///
/// Provides temporal comparison operations.
class DateTimeColumn extends Column<DateTime> {
  const DateTimeColumn(super.name, super.table);

  /// Strictly before: `column < @value`.
  Expression before(DateTime value) => Comparison(qualified, '<', value);

  /// Strictly after: `column > @value`.
  Expression after(DateTime value) => Comparison(qualified, '>', value);

  /// On or before: `column <= @value`.
  Expression onOrBefore(DateTime value) => Comparison(qualified, '<=', value);

  /// On or after: `column >= @value`.
  Expression onOrAfter(DateTime value) => Comparison(qualified, '>=', value);

  /// Between two dates (inclusive): `column BETWEEN @start AND @end`.
  Expression between(DateTime start, DateTime end) =>
      Between(qualified, start, end);
}
