/// An ORDER BY expression: `column ASC` or `column DESC`.
class OrderExpression {
  /// The qualified column name (e.g. `'users.created_at'`).
  final String column;

  /// Whether to sort in descending order.
  final bool descending;

  const OrderExpression(this.column, {this.descending = false});

  /// Renders to SQL fragment (e.g. `users.created_at DESC`).
  String toSql() => descending ? '$column DESC' : '$column ASC';
}
