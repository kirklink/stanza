import 'package:postgres/postgres.dart' as pg;

import 'exception.dart';
import 'parameter.dart';
import 'query.dart';
import 'result.dart';
import 'table.dart';

/// Callback type for session-based execution (transactions, multi-query).
typedef SessionBlock<T> = Future<T> Function(StanzaSession session);

/// PostgreSQL connection pool manager.
///
/// Create via [Stanza.url] or [Stanza.pool], then use [execute], [stream],
/// [run], or [transaction] to interact with the database.
///
/// ```dart
/// final db = Stanza.url('postgresql://user:pass@host/dbname');
/// final result = await db.execute(selectQuery);
/// ```
class Stanza {
  final pg.Pool _pool;

  /// Instance cache keyed by connection identifier.
  static final _instances = <String, Stanza>{};

  Stanza._(this._pool);

  /// Creates a connection pool from a PostgreSQL URL.
  ///
  /// Reuses existing pools for the same URL.
  factory Stanza.url(
    String url, {
    int maxConnections = 25,
    pg.SslMode? sslMode,
    Duration? connectTimeout,
    Duration? queryTimeout,
    String? applicationName,
  }) {
    if (_instances.containsKey(url)) return _instances[url]!;

    final endpoint = pg.Endpoint(
      host: Uri.parse(url).host,
      port: Uri.parse(url).port == 0 ? 5432 : Uri.parse(url).port,
      database: Uri.parse(url).pathSegments.isNotEmpty
          ? Uri.parse(url).pathSegments.first
          : '',
      username: Uri.parse(url).userInfo.split(':').first,
      password: Uri.parse(url).userInfo.contains(':')
          ? Uri.parse(url).userInfo.split(':').last
          : null,
    );

    final pool = pg.Pool.withEndpoints(
      [endpoint],
      settings: pg.PoolSettings(
        maxConnectionCount: maxConnections,
        sslMode: sslMode ?? pg.SslMode.disable,
        connectTimeout: connectTimeout ?? const Duration(seconds: 15),
        queryTimeout: queryTimeout ?? const Duration(seconds: 30),
        applicationName: applicationName,
      ),
    );

    final instance = Stanza._(pool);
    _instances[url] = instance;
    return instance;
  }

  /// Creates a Stanza instance from an existing postgres Pool.
  factory Stanza.pool(pg.Pool pool) => Stanza._(pool);

  /// Executes a query and returns mapped results.
  Future<QueryResult<T>> execute<T, D extends TableDescriptor<T>>(
    Query<T, D> query,
  ) async {
    final params = ParameterCollector();
    final sql = query.toSql(params);

    try {
      final pgResult = await _pool.execute(
        pg.Sql.named(sql),
        parameters: params.values,
      );

      final rows = pgResult.map(_pgRowToMap).toList();
      return QueryResult(
        rows: rows,
        table: query.table,
        affectedRows: pgResult.affectedRows,
      );
    } on pg.PgException catch (e) {
      throw StanzaException('Query execution failed', cause: e);
    }
  }

  /// Executes raw SQL with optional named parameters.
  Future<QueryResult<Never>> rawExecute(
    String sql, {
    Map<String, dynamic>? parameters,
  }) async {
    try {
      final pgResult = await _pool.execute(
        pg.Sql.named(sql),
        parameters: parameters ?? {},
      );

      final rows = pgResult.map(_pgRowToMap).toList();
      return QueryResult(
        rows: rows,
        affectedRows: pgResult.affectedRows,
      );
    } on pg.PgException catch (e) {
      throw StanzaException('Raw query execution failed', cause: e);
    }
  }

  /// Runs multiple queries on a single connection (no transaction).
  Future<T> run<T>(SessionBlock<T> block) async {
    return _pool.run((pgSession) async {
      final session = StanzaSession._(pgSession);
      return block(session);
    });
  }

  /// Runs queries in a transaction. Rolls back on error.
  Future<T> transaction<T>(SessionBlock<T> block) async {
    return _pool.runTx((pgSession) async {
      final session = StanzaSession._(pgSession);
      return block(session);
    });
  }

  /// Streams query results row by row without buffering.
  Stream<T> stream<T, D extends TableDescriptor<T>>(
    Query<T, D> query,
  ) async* {
    final params = ParameterCollector();
    final sql = query.toSql(params);

    await for (final row in _pool.execute(
      pg.Sql.named(sql),
      parameters: params.values,
    ).asStream().asyncExpand((result) => Stream.fromIterable(result))) {
      yield query.table.fromRow(_pgRowToMap(row));
    }
  }

  /// Closes the connection pool.
  Future<void> close() async {
    await _pool.close();
    _instances.removeWhere((_, v) => v == this);
  }

  static Map<String, dynamic> _pgRowToMap(pg.ResultRow row) {
    final map = <String, dynamic>{};
    for (final col in row.toColumnMap().entries) {
      map[col.key] = col.value;
    }
    return map;
  }
}

/// A single database session for use in [Stanza.run] and [Stanza.transaction].
///
/// Provides the same query execution API as [Stanza] but on a single connection.
class StanzaSession {
  final pg.Session _session;

  StanzaSession._(this._session);

  /// Executes a query and returns mapped results.
  Future<QueryResult<T>> execute<T, D extends TableDescriptor<T>>(
    Query<T, D> query,
  ) async {
    final params = ParameterCollector();
    final sql = query.toSql(params);

    try {
      final pgResult = await _session.execute(
        pg.Sql.named(sql),
        parameters: params.values,
      );

      final rows = pgResult.map(Stanza._pgRowToMap).toList();
      return QueryResult(
        rows: rows,
        table: query.table,
        affectedRows: pgResult.affectedRows,
      );
    } on pg.PgException catch (e) {
      throw StanzaException('Query execution failed', cause: e);
    }
  }

  /// Executes raw SQL with optional named parameters.
  Future<QueryResult<Never>> rawExecute(
    String sql, {
    Map<String, dynamic>? parameters,
  }) async {
    try {
      final pgResult = await _session.execute(
        pg.Sql.named(sql),
        parameters: parameters ?? {},
      );

      final rows = pgResult.map(Stanza._pgRowToMap).toList();
      return QueryResult(
        rows: rows,
        affectedRows: pgResult.affectedRows,
      );
    } on pg.PgException catch (e) {
      throw StanzaException('Raw query execution failed', cause: e);
    }
  }
}
