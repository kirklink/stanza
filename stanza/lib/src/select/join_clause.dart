import 'package:stanza/src/query_clause.dart';
import 'package:stanza/src/field.dart';
import 'package:stanza/src/table.dart';

/// The type of SQL JOIN to perform.
enum JoinType { inner, left, right, cross }

/// Represents a SQL JOIN clause.
///
/// Created via [SelectQuery.innerJoin], [SelectQuery.leftJoin],
/// [SelectQuery.rightJoin], or [SelectQuery.crossJoin].
class JoinClause implements QueryClause {
  final JoinType type;
  final Table joinTable;
  Field? _leftField;
  Field? _rightField;

  JoinClause(this.type, this.joinTable);

  /// Specify the ON condition for this join.
  ///
  /// [left] is the field from the source or previously joined table.
  /// [right] is the field from the table being joined.
  void on(Field left, Field right) {
    _leftField = left;
    _rightField = right;
  }

  @override
  String get clause {
    final keyword = switch (type) {
      JoinType.inner => 'INNER JOIN',
      JoinType.left => 'LEFT JOIN',
      JoinType.right => 'RIGHT JOIN',
      JoinType.cross => 'CROSS JOIN',
    };
    if (type == JoinType.cross) return '$keyword ${joinTable.$name}';
    return '$keyword ${joinTable.$name} ON ${_leftField!.qualifiedName} = ${_rightField!.qualifiedName}';
  }

  @override
  JoinClause clone() {
    final c = JoinClause(type, joinTable);
    c._leftField = _leftField;
    c._rightField = _rightField;
    return c;
  }
}
