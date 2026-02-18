import 'package:stanza/src/stanza_exception.dart';
import 'package:stanza/src/query.dart';
import 'package:stanza/src/field.dart';
import 'package:stanza/src/insert/insert_clause.dart';
import 'package:stanza/src/shared/returning_clause.dart';

/// Base class for an insert query.
///
/// Takes the generated code table from a [StanzaEntity].
class InsertQuery extends Query with ReturningClause {
  InsertClause _insert = InsertClause();

  InsertQuery(super.table);

  @override
  String statement({bool pretty = false}) {
    final br = pretty ? '\n' : ' ';
    final tableName = table.$name;
    final insert = _insert.clause;
    final ret = returningClause;

    final buf = StringBuffer('INSERT INTO $tableName$br$insert');
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

  /// Reproduce a partial query to use in a loop or other dynamic pattern.
  @override
  InsertQuery fork() {
    final q = InsertQuery(table);
    q.importSubstitutionValues(substitutionValues);
    q._insert = _insert.clone();
    q.importReturningClause(this);
    return q;
  }
}
