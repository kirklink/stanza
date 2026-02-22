import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:stanza/stanza.dart';

/// SQLite database adapter for Stanza ORM.
///
/// Implements [DatabaseAdapter] using `package:sqlite3` (FFI bindings).
/// Single-connection, synchronous driver wrapped in async interface.
///
/// ```dart
/// final db = StanzaSqlite.open('app.db');
/// final result = await db.execute(selectQuery);
/// await db.close();
/// ```
class StanzaSqlite implements DatabaseAdapter {
  final sqlite3.Database _db;
  final bool _ownsDatabase;

  StanzaSqlite._(this._db, {bool ownsDatabase = true})
      : _ownsDatabase = ownsDatabase;

  /// Opens a file-based SQLite database.
  ///
  /// Enables foreign key enforcement and WAL journal mode by default.
  factory StanzaSqlite.open(
    String path, {
    bool enableForeignKeys = true,
    bool walMode = true,
  }) {
    final db = sqlite3.sqlite3.open(path);
    if (enableForeignKeys) db.execute('PRAGMA foreign_keys = ON;');
    if (walMode) db.execute('PRAGMA journal_mode = WAL;');
    return StanzaSqlite._(db);
  }

  /// Opens an in-memory SQLite database (ideal for testing).
  ///
  /// Enables foreign key enforcement by default.
  factory StanzaSqlite.memory({bool enableForeignKeys = true}) {
    final db = sqlite3.sqlite3.openInMemory();
    if (enableForeignKeys) db.execute('PRAGMA foreign_keys = ON;');
    return StanzaSqlite._(db);
  }

  /// Wraps a pre-existing [sqlite3.Database] instance.
  ///
  /// Use this to share a database managed by another system (e.g., Cellar).
  /// When [ownsDatabase] is `false` (the default), [close] will NOT dispose
  /// the database — the caller retains lifecycle ownership.
  factory StanzaSqlite.fromDatabase(
    sqlite3.Database db, {
    bool ownsDatabase = false,
  }) {
    return StanzaSqlite._(db, ownsDatabase: ownsDatabase);
  }

  @override
  ParameterCollector createParameterCollector() =>
      ParameterCollector(placeholderPrefix: ':');

  @override
  Future<QueryResult<T>> execute<T, D extends TableDescriptor<T>>(
    Query<T, D> query,
  ) async {
    final params = createParameterCollector();
    final sql = query.toSql(params);
    final sqliteParams = _prepareSqliteParams(params.values);

    try {
      final stmt = _db.prepare(sql);
      try {
        final result = stmt.selectWith(
          sqlite3.StatementParameters.named(sqliteParams),
        );
        final schema = query.table.$schema;
        final rows = result.map((row) {
          final map = Map<String, dynamic>.from(row);
          return schema != null ? _convertRowFromSqlite(map, schema) : map;
        }).toList();
        return QueryResult(
          rows: rows,
          table: query.table,
          affectedRows: _db.updatedRows,
        );
      } finally {
        stmt.dispose();
      }
    } on sqlite3.SqliteException catch (e) {
      throw StanzaException('Query execution failed', cause: e);
    }
  }

  @override
  Future<QueryResult<Never>> rawExecute(
    String sql, {
    Map<String, dynamic>? parameters,
  }) async {
    try {
      final sqliteParams = parameters != null
          ? _prepareSqliteParams(parameters)
          : const <String, Object?>{};
      final stmt = _db.prepare(sql);
      try {
        final result = stmt.selectWith(
          sqlite3.StatementParameters.named(sqliteParams),
        );
        final rows =
            result.map((row) => Map<String, dynamic>.from(row)).toList();
        return QueryResult(rows: rows, affectedRows: _db.updatedRows);
      } finally {
        stmt.dispose();
      }
    } on sqlite3.SqliteException catch (e) {
      throw StanzaException('Raw query execution failed', cause: e);
    }
  }

  @override
  Future<T> run<T>(AdapterSessionBlock<T> block) async {
    final session = SqliteSession._(_db);
    return block(session);
  }

  @override
  Future<T> transaction<T>(AdapterSessionBlock<T> block) async {
    _db.execute('BEGIN');
    try {
      final session = SqliteSession._(_db);
      final result = await block(session);
      _db.execute('COMMIT');
      return result;
    } catch (e) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  @override
  Future<List<R>> rawQuery<R>(
    String sql, {
    Map<String, dynamic>? parameters,
    required R Function(Map<String, dynamic> row) mapper,
  }) async {
    final result = await rawExecute(sql, parameters: parameters);
    return result.rows.map(mapper).toList();
  }

  @override
  Future<void> close() async {
    if (_ownsDatabase) _db.dispose();
  }

  /// Prefixes parameter keys and converts Dart types to SQLite-compatible values.
  ///
  /// - Keys: `'p0'` → `':p0'` (sqlite3 expects prefixed keys)
  /// - Values: `bool` → `int` (0/1), `DateTime` → `String` (ISO 8601 UTC)
  static Map<String, Object?> _prepareSqliteParams(
    Map<String, dynamic> params,
  ) {
    return params.map((key, value) {
      final prefixedKey = key.startsWith(':') ? key : ':$key';
      return MapEntry(prefixedKey, _convertValueForSqlite(value));
    });
  }

  /// Converts a single Dart value to its SQLite storage representation.
  static Object? _convertValueForSqlite(dynamic value) {
    return switch (value) {
      null => null,
      bool b => b ? 1 : 0,
      DateTime dt => dt.toUtc().toIso8601String(),
      _ => value,
    };
  }

  /// Converts a SQLite result row to Dart types using schema metadata.
  ///
  /// Reverses the storage conversions:
  /// - `INTEGER` (0/1) → `bool` for columns with `dartTypeName == 'bool'`
  /// - `TEXT` (ISO 8601) → `DateTime` for columns with `dartTypeName == 'DateTime'`
  static Map<String, dynamic> _convertRowFromSqlite(
    Map<String, dynamic> row,
    SchemaTable schema,
  ) {
    final converted = <String, dynamic>{};
    for (final entry in row.entries) {
      final value = entry.value;
      if (value == null) {
        converted[entry.key] = null;
        continue;
      }
      final col = schema.columnByName(entry.key);
      converted[entry.key] = switch (col?.dartTypeName) {
        'bool' => value == 1,
        'DateTime' => DateTime.parse(value as String),
        _ => value,
      };
    }
    return converted;
  }
}

/// A session for use within [StanzaSqlite.run] and [StanzaSqlite.transaction].
///
/// In SQLite, sessions share the same underlying connection since there is
/// no connection pool. The session ensures consistent execution context
/// within `run()` and `transaction()` blocks.
class SqliteSession implements SessionAdapter {
  final sqlite3.Database _db;

  SqliteSession._(this._db);

  @override
  Future<QueryResult<T>> execute<T, D extends TableDescriptor<T>>(
    Query<T, D> query,
  ) async {
    final params = ParameterCollector(placeholderPrefix: ':');
    final sql = query.toSql(params);
    final sqliteParams = StanzaSqlite._prepareSqliteParams(params.values);

    try {
      final stmt = _db.prepare(sql);
      try {
        final result = stmt.selectWith(
          sqlite3.StatementParameters.named(sqliteParams),
        );
        final schema = query.table.$schema;
        final rows = result.map((row) {
          final map = Map<String, dynamic>.from(row);
          return schema != null
              ? StanzaSqlite._convertRowFromSqlite(map, schema)
              : map;
        }).toList();
        return QueryResult(
          rows: rows,
          table: query.table,
          affectedRows: _db.updatedRows,
        );
      } finally {
        stmt.dispose();
      }
    } on sqlite3.SqliteException catch (e) {
      throw StanzaException('Query execution failed', cause: e);
    }
  }

  @override
  Future<QueryResult<Never>> rawExecute(
    String sql, {
    Map<String, dynamic>? parameters,
  }) async {
    try {
      final sqliteParams = parameters != null
          ? StanzaSqlite._prepareSqliteParams(parameters)
          : const <String, Object?>{};
      final stmt = _db.prepare(sql);
      try {
        final result = stmt.selectWith(
          sqlite3.StatementParameters.named(sqliteParams),
        );
        final rows =
            result.map((row) => Map<String, dynamic>.from(row)).toList();
        return QueryResult(rows: rows, affectedRows: _db.updatedRows);
      } finally {
        stmt.dispose();
      }
    } on sqlite3.SqliteException catch (e) {
      throw StanzaException('Raw query execution failed', cause: e);
    }
  }

  @override
  Future<List<R>> rawQuery<R>(
    String sql, {
    Map<String, dynamic>? parameters,
    required R Function(Map<String, dynamic> row) mapper,
  }) async {
    final result = await rawExecute(sql, parameters: parameters);
    return result.rows.map(mapper).toList();
  }
}
