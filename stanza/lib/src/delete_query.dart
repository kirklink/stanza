import 'expression.dart';
import 'parameter.dart';
import 'query.dart';
import 'table.dart';

/// A type-safe DELETE query builder.
///
/// ```dart
/// final query = DeleteQuery(userTable)
///     .where((t) => t.id.equals(1))
///     .returning();
/// ```
class DeleteQuery<T, D extends TableDescriptor<T>> extends Query<T, D> {
  final List<Expression> _wheres = [];
  bool _returning = false;
  bool _allowUnsafe = false;

  DeleteQuery(super.table);

  /// Adds a WHERE condition. Multiple calls are combined with AND.
  DeleteQuery<T, D> where(Expression Function(D t) predicate) {
    _wheres.add(predicate(table));
    return this;
  }

  /// Adds RETURNING * to get the deleted row(s) back.
  DeleteQuery<T, D> returning() {
    _returning = true;
    return this;
  }

  /// Allows DELETE without a WHERE clause (deletes all rows).
  DeleteQuery<T, D> allowUnsafe() {
    _allowUnsafe = true;
    return this;
  }

  @override
  String toSql(ParameterCollector params) {
    if (_wheres.isEmpty && !_allowUnsafe) {
      throw StateError(
        'DeleteQuery requires a WHERE clause. '
        'Call .allowUnsafe() to delete all rows.',
      );
    }

    final buf = StringBuffer();

    // DELETE FROM table
    buf.write('DELETE FROM ${table.tableName}');

    // WHERE
    if (_wheres.isNotEmpty) {
      buf.write(' WHERE ');
      if (_wheres.length == 1) {
        buf.write(_wheres.first.toSql(params));
      } else {
        final combined = _wheres.reduce((a, b) => And(a, b));
        buf.write(combined.toSql(params));
      }
    }

    // RETURNING
    if (_returning) {
      buf.write(' RETURNING *');
    }

    return buf.toString();
  }
}
