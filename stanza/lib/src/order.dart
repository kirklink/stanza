/// An ORDER BY expression: `column ASC` or `column DESC`.
class OrderExpression {
  final String column;
  final bool descending;

  const OrderExpression(this.column, {this.descending = false});

  /// Renders to SQL fragment (e.g. `users.created_at DESC`).
  String toSql() => descending ? '$column DESC' : '$column ASC';
}
