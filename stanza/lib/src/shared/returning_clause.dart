import 'package:stanza/src/field.dart';
import 'package:stanza/src/query.dart';

/// Mixin that adds RETURNING clause support to INSERT, UPDATE, and DELETE queries.
///
/// PostgreSQL's RETURNING clause returns the affected rows as if they were
/// selected, eliminating the need for a follow-up SELECT after a write.
mixin ReturningClause on Query {
  final List<String> _returningFields = [];
  bool _returningStar = false;

  /// Return all columns from the affected rows.
  ///
  /// ```dart
  /// var q = InsertQuery(Animal.$table)
  ///   ..insertEntity(animal)
  ///   ..returningStar();
  /// ```
  void returningStar() {
    _returningStar = true;
  }

  /// Return specific fields from the affected rows.
  ///
  /// ```dart
  /// var q = InsertQuery(Animal.$table)
  ///   ..insertEntity(animal)
  ///   ..returning([Animal.$table.id, Animal.$table.name]);
  /// ```
  void returning(List<Field> fields) {
    for (final f in fields) {
      _returningFields.add(f.sql);
    }
  }

  /// The RETURNING clause string, or null if not set.
  String? get returningClause {
    if (_returningStar) return 'RETURNING *';
    if (_returningFields.isNotEmpty) {
      return 'RETURNING ${_returningFields.join(', ')}';
    }
    return null;
  }

  /// Clones the returning state into another clause.
  void importReturningClause(ReturningClause other) {
    _returningStar = other._returningStar;
    _returningFields.addAll(other._returningFields);
  }
}
