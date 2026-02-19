import 'package:stanza/src/stanza_exception.dart';
import 'package:stanza/src/query.dart';
import 'package:stanza/src/field.dart';
import 'package:stanza/src/insert/insert_clause.dart';
import 'package:stanza/src/insert/conflict_clause.dart';
import 'package:stanza/src/shared/returning_clause.dart';

/// Callback for building the SET clause of ON CONFLICT ... DO UPDATE.
typedef ConflictUpdateBuilder = void Function(ConflictSetBuilder set);

/// Base class for an insert query.
///
/// Takes the generated code table from a [StanzaEntity].
class InsertQuery extends Query with ReturningClause {
  InsertClause _insert = InsertClause();
  ConflictClause? _conflict;

  InsertQuery(super.table);

  @override
  String statement({bool pretty = false}) {
    final br = pretty ? '\n' : ' ';
    final tableName = table.$name;
    final insert = _insert.clause;
    final ret = returningClause;

    final buf = StringBuffer('INSERT INTO $tableName$br$insert');
    if (_conflict != null) buf.writeAll([br, _conflict!.clause]);
    if (ret != null) buf.writeAll([br, ret]);
    return buf.toString();
  }

  /// Insert a [value] into a [field].
  void insert(Field field, dynamic value) {
    _insert.insert(field.name, value, this);
  }

  /// Insert a complete [StanzaEntity] into the database.
  void insertEntity<T>(T entity) {
    if (table.$type != T) {
      throw StanzaException(
          'Mismatch. The entity is Type $T. The table is type ${table.$type}');
    }
    final map = table.toDb(entity);
    map.forEach((k, v) {
      _insert.insert(k, v, this);
    });
  }

  /// Insert multiple entities in a single batch statement.
  ///
  /// Produces `INSERT INTO table (cols) VALUES (...), (...), (...)`.
  /// Throws [StanzaException] if [entities] is empty or the type doesn't match.
  void insertEntities<T>(List<T> entities) {
    if (entities.isEmpty) {
      throw StanzaException(
          'insertEntities() requires at least one entity.');
    }
    if (table.$type != T) {
      throw StanzaException(
          'Mismatch. The entity is Type $T. The table is type ${table.$type}');
    }
    for (final entity in entities) {
      final map = table.toDb(entity);
      _insert.addRow(map, this);
    }
  }

  /// Add an ON CONFLICT ... DO UPDATE SET clause (upsert).
  ///
  /// [target] specifies the conflict columns (typically a unique constraint).
  /// [doUpdate] receives a [ConflictSetBuilder] for specifying which columns
  /// to update on conflict.
  ///
  /// ```dart
  /// q.onConflict(
  ///   target: [table.name],
  ///   doUpdate: (set) => set
  ///     ..column(table.color).string('updated')
  ///     ..column(table.legs).integer(4),
  /// );
  /// ```
  void onConflict({
    required List<Field> target,
    required ConflictUpdateBuilder doUpdate,
  }) {
    final builder = ConflictSetBuilder(this);
    doUpdate(builder);
    _conflict = ConflictClause.doUpdate(
      target: target,
      setBuilder: builder,
    );
  }

  /// Add an ON CONFLICT ... DO NOTHING clause.
  ///
  /// [target] specifies the conflict columns (typically a unique constraint).
  void onConflictDoNothing({required List<Field> target}) {
    _conflict = ConflictClause.doNothing(target: target);
  }

  /// Reproduce a partial query to use in a loop or other dynamic pattern.
  @override
  InsertQuery fork() {
    final q = InsertQuery(table);
    q.importSubstitutionValues(substitutionValues);
    q._insert = _insert.clone();
    q._conflict = _conflict?.clone(q);
    q.importReturningClause(this);
    return q;
  }
}
