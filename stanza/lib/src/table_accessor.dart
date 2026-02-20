import 'column.dart';
import 'delete_query.dart';
import 'insert_query.dart';
import 'select_query.dart';
import 'stanza.dart';
import 'table.dart';
import 'update_query.dart';

/// Provides typed CRUD operations for a specific entity table.
///
/// Created by the generated `$AppDatabase` class. Binds a [TableDescriptor]
/// to a [Stanza] connection, enabling fluent query building and execution.
///
/// ```dart
/// // db.users is a TableAccessor<User, $UserTable>
/// final users = await db.users
///     .select()
///     .where((t) => t.email.like('%@example.com'))
///     .limit(10)
///     .run(db.connection);
/// ```
class TableAccessor<T, D extends TableDescriptor<T>> {
  /// The table descriptor providing typed columns and row mapping.
  final D descriptor;

  final Stanza _db;

  /// Creates an accessor bound to a table descriptor and database connection.
  TableAccessor(this.descriptor, this._db);

  /// Starts a SELECT query for this table.
  SelectQuery<T, D> select() => SelectQuery<T, D>(descriptor);

  /// Inserts a single row and returns the created entity.
  ///
  /// Pass the result of a generated companion's `toRow()`:
  /// ```dart
  /// final user = await db.users.insertRow(
  ///   UserInsert(email: 'foo@bar.com', name: 'Kirk').toRow(),
  /// );
  /// ```
  Future<T> insertRow(Map<String, dynamic> values) async {
    final query = InsertQuery<T, D>(descriptor).values(values).returning();
    final result = await _db.execute(query);
    return result.entities.first;
  }

  /// Inserts multiple rows and returns the created entities.
  Future<List<T>> insertRows(List<Map<String, dynamic>> rows) async {
    final query = InsertQuery<T, D>(descriptor).valuesList(rows).returning();
    final result = await _db.execute(query);
    return result.entities;
  }

  /// Finds an entity by its primary key value.
  ///
  /// Returns null if not found.
  Future<T?> findById(Object id) async {
    final pk = descriptor.primaryKey;
    final query = SelectQuery<T, D>(descriptor)
        .where((_) => pk.equals(id as dynamic));
    final result = await _db.execute(query);
    return result.firstOrNull;
  }

  /// Starts an UPDATE query with the given values.
  ///
  /// Pass the result of a generated companion's `toRow()`:
  /// ```dart
  /// await db.users
  ///     .updateWith(UserUpdate(name: 'New Name').toRow())
  ///     .where((t) => t.id.equals(1))
  ///     .run(db.connection);
  /// ```
  UpdateQuery<T, D> updateWith(Map<String, dynamic> values) =>
      UpdateQuery<T, D>(descriptor, values);

  /// Starts a DELETE query for this table.
  DeleteQuery<T, D> delete() => DeleteQuery<T, D>(descriptor);

  /// Inserts or updates a row based on a conflict target.
  Future<T> upsertRow(
    Map<String, dynamic> values, {
    required List<Column> Function(D t) conflictTarget,
    required Map<String, dynamic> updateValues,
  }) async {
    final query = InsertQuery<T, D>(descriptor)
        .values(values)
        .onConflict(
          target: conflictTarget(descriptor),
          doUpdate: updateValues,
        )
        .returning();
    final result = await _db.execute(query);
    return result.entities.first;
  }
}

/// Extension to execute queries directly against a [Stanza] connection.
extension ExecutableSelectQuery<T, D extends TableDescriptor<T>>
    on SelectQuery<T, D> {
  /// Executes this SELECT query and returns mapped entities.
  Future<List<T>> run(Stanza db) async {
    final result = await db.execute(this);
    return result.entities;
  }
}

/// Extension to execute UPDATE queries directly.
extension ExecutableUpdateQuery<T, D extends TableDescriptor<T>>
    on UpdateQuery<T, D> {
  /// Executes this UPDATE query and returns the affected row count.
  Future<int> run(Stanza db) async {
    final result = await db.execute(this);
    return result.affectedRows;
  }

  /// Executes this UPDATE with RETURNING and returns the updated entities.
  Future<List<T>> runReturning(Stanza db) async {
    returning();
    final result = await db.execute(this);
    return result.entities;
  }
}

/// Extension to execute DELETE queries directly.
extension ExecutableDeleteQuery<T, D extends TableDescriptor<T>>
    on DeleteQuery<T, D> {
  /// Executes this DELETE query and returns the affected row count.
  Future<int> run(Stanza db) async {
    final result = await db.execute(this);
    return result.affectedRows;
  }

  /// Executes this DELETE with RETURNING and returns the deleted entities.
  Future<List<T>> runReturning(Stanza db) async {
    returning();
    final result = await db.execute(this);
    return result.entities;
  }
}
