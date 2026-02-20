import 'expression.dart';
import 'parameter.dart';
import 'query.dart';
import 'table.dart';

/// A type-safe UPDATE query builder.
///
/// ```dart
/// final query = UpdateQuery(userTable, {'name': 'New Name'})
///     .where((t) => t.id.equals(1))
///     .returning();
/// ```
class UpdateQuery<T, D extends TableDescriptor<T>> extends Query<T, D> {
  final Map<String, dynamic> _values;
  final List<Expression> _wheres = [];
  bool _returning = false;
  bool _allowUnsafe = false;

  UpdateQuery(super.table, this._values);

  /// Adds a WHERE condition. Multiple calls are combined with AND.
  UpdateQuery<T, D> where(Expression Function(D t) predicate) {
    _wheres.add(predicate(table));
    return this;
  }

  /// Adds RETURNING * to get the updated row(s) back.
  UpdateQuery<T, D> returning() {
    _returning = true;
    return this;
  }

  /// Allows UPDATE without a WHERE clause (updates all rows).
  UpdateQuery<T, D> allowUnsafe() {
    _allowUnsafe = true;
    return this;
  }

  @override
  String toSql(ParameterCollector params) {
    if (_values.isEmpty) {
      throw StateError('UpdateQuery requires at least one column to update');
    }

    if (_wheres.isEmpty && !_allowUnsafe) {
      throw StateError(
        'UpdateQuery requires a WHERE clause. '
        'Call .allowUnsafe() to update all rows.',
      );
    }

    final buf = StringBuffer();

    // UPDATE table SET col = @param, ...
    buf.write('UPDATE ${table.tableName} SET ');
    final sets = <String>[];
    for (final entry in _values.entries) {
      sets.add('${entry.key} = ${params.add(entry.value)}');
    }
    buf.write(sets.join(', '));

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
