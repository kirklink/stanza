import 'column.dart';
import 'parameter.dart';
import 'query.dart';
import 'table.dart';

/// A type-safe INSERT query builder.
///
/// ```dart
/// final query = InsertQuery(userTable)
///     .values({'email': 'foo@bar.com', 'name': 'Kirk'})
///     .returning();
/// ```
class InsertQuery<T, D extends TableDescriptor<T>> extends Query<T, D> {
  final List<Map<String, dynamic>> _rows = [];
  bool _returning = false;
  _ConflictClause? _conflict;

  /// Creates an INSERT query for [table].
  InsertQuery(super.table);

  /// Sets the values to insert (from a companion's `toRow()`).
  InsertQuery<T, D> values(Map<String, dynamic> row) {
    _rows.add(row);
    return this;
  }

  /// Sets multiple rows for batch insert.
  InsertQuery<T, D> valuesList(List<Map<String, dynamic>> rows) {
    _rows.addAll(rows);
    return this;
  }

  /// Adds RETURNING * to get the inserted row(s) back.
  InsertQuery<T, D> returning() {
    _returning = true;
    return this;
  }

  /// Adds ON CONFLICT DO UPDATE (upsert).
  InsertQuery<T, D> onConflict({
    required List<Column> target,
    required Map<String, dynamic> doUpdate,
  }) {
    _conflict = _ConflictClause(
      target: target,
      doUpdate: doUpdate,
      doNothing: false,
    );
    return this;
  }

  /// Adds ON CONFLICT DO NOTHING.
  InsertQuery<T, D> onConflictDoNothing({required List<Column> target}) {
    _conflict = _ConflictClause(
      target: target,
      doUpdate: null,
      doNothing: true,
    );
    return this;
  }

  /// Generates the INSERT SQL statement.
  ///
  /// Throws [StateError] if no values have been provided via [values] or [valuesList].
  @override
  String toSql(ParameterCollector params) {
    if (_rows.isEmpty) {
      throw StateError('InsertQuery requires at least one row of values');
    }

    final buf = StringBuffer();

    // All rows must have the same columns (use first row's keys)
    final columnNames = _rows.first.keys.toList();

    // INSERT INTO table (col1, col2, ...)
    buf.write('INSERT INTO ${table.tableName} ');
    buf.write('(${columnNames.join(', ')})');

    // VALUES
    buf.write(' VALUES ');
    final rowSqls = <String>[];
    for (final row in _rows) {
      final placeholders =
          columnNames.map((col) => params.add(row[col])).join(', ');
      rowSqls.add('($placeholders)');
    }
    buf.write(rowSqls.join(', '));

    // ON CONFLICT
    if (_conflict != null) {
      final targetCols =
          _conflict!.target.map((c) => c.name).join(', ');
      buf.write(' ON CONFLICT ($targetCols)');
      if (_conflict!.doNothing) {
        buf.write(' DO NOTHING');
      } else if (_conflict!.doUpdate != null) {
        buf.write(' DO UPDATE SET ');
        final sets = <String>[];
        for (final entry in _conflict!.doUpdate!.entries) {
          sets.add('${entry.key} = ${params.add(entry.value)}');
        }
        buf.write(sets.join(', '));
      }
    }

    // RETURNING
    if (_returning) {
      buf.write(' RETURNING *');
    }

    return buf.toString();
  }
}

class _ConflictClause {
  final List<Column> target;
  final Map<String, dynamic>? doUpdate;
  final bool doNothing;

  _ConflictClause({
    required this.target,
    required this.doUpdate,
    required this.doNothing,
  });
}
