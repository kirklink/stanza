import 'package:postgres/postgres.dart' as pg;
import 'package:stanza/src/delete/delete_query.dart';
import 'package:stanza/src/postgres_credentials.dart';
import 'package:stanza/src/query.dart';
import 'package:stanza/src/query_result.dart';
import 'package:stanza/src/stanza_exception.dart';
import 'package:stanza/src/update/update_query.dart';

/// Callback type for running multiple queries on a single session.
typedef SessionBlock<T> = Future<T> Function(StanzaSession session);

/// A wrapper around a postgres v3 session for executing queries.
///
/// Used inside [Stanza.run] and [Stanza.runTransaction] callbacks.
class StanzaSession {
  final pg.Session _session;

  StanzaSession._(this._session);

  /// Executes a [Query] within this session.
  ///
  /// [overrideSafety]: Set to true to allow UPDATE/DELETE queries without WHERE clauses.
  Future<QueryResult<T>> execute<T>(Query query,
      {bool overrideSafety = false}) async {
    _checkSafety(query, overrideSafety);
    final result = await _session.execute(
      pg.Sql.named(query.statement()),
      parameters: query.substitutionValues,
    );
    return _toQueryResult<T>(result, query);
  }

  /// Stream query results row by row within this session.
  ///
  /// Uses postgres v3 prepared statements for true streaming — rows arrive
  /// one at a time without buffering the full result set in memory.
  Stream<Result<T>> stream<T>(Query query) async* {
    final stmt = await _session.prepare(pg.Sql.named(query.statement()));
    try {
      await for (final row in stmt.bind(query.substitutionValues)) {
        yield _toSingleResult<T>(row, query);
      }
    } finally {
      await stmt.dispose();
    }
  }

  /// Execute a raw SQL string within this session.
  ///
  /// Use for DDL statements, migrations, or queries not expressible
  /// through the Stanza query builder.
  Future<pg.Result> rawExecute(String sql,
      {Map<String, dynamic>? parameters}) async {
    return _session.execute(
      pg.Sql.named(sql),
      parameters: parameters,
    );
  }
}

/// The main class for creating and using the Stanza database interface.
///
/// Stanza wraps a postgres v3 connection [Pool] and provides a type-safe
/// query execution layer.
///
/// ```dart
/// final stanza = Stanza.tcp(creds, maxConnections: 10);
/// final result = await stanza.execute<Animal>(selectQuery);
/// ```
class Stanza {
  final pg.Pool _pool;

  Stanza._(this._pool);

  /// Create a Stanza instance using a TCP connection.
  ///
  /// [maxConnections]: Maximum number of connections in the pool (default: 25).
  /// [sslMode]: SSL mode for the connection (disable, require, verifyFull).
  /// [connectTimeout]: Maximum time to wait for a connection.
  /// [queryTimeout]: Maximum time to wait for a query to complete.
  /// [applicationName]: Application name shown in `pg_stat_activity`.
  factory Stanza.tcp(
    PostgresCredentials creds, {
    int maxConnections = 25,
    pg.SslMode? sslMode,
    Duration? connectTimeout,
    Duration? queryTimeout,
    String? applicationName,
  }) {
    final id = '${creds.host}:${creds.port}|${creds.db}';
    if (!_instances.containsKey(id)) {
      final pool = pg.Pool.withEndpoints(
        [
          pg.Endpoint(
            host: creds.host,
            port: creds.port,
            database: creds.db,
            username: creds.username,
            password: creds.password,
          ),
        ],
        settings: pg.PoolSettings(
          maxConnectionCount: maxConnections,
          sslMode: sslMode,
          connectTimeout: connectTimeout,
          queryTimeout: queryTimeout,
          applicationName: applicationName,
        ),
      );
      _instances[id] = Stanza._(pool);
    }
    return _instances[id]!;
  }

  /// Create a Stanza instance using a Unix socket connection.
  ///
  /// [maxConnections]: Maximum number of connections in the pool (default: 25).
  /// [connectTimeout]: Maximum time to wait for a connection.
  /// [queryTimeout]: Maximum time to wait for a query to complete.
  /// [applicationName]: Application name shown in `pg_stat_activity`.
  factory Stanza.unix(
    PostgresCredentials creds, {
    int maxConnections = 25,
    Duration? connectTimeout,
    Duration? queryTimeout,
    String? applicationName,
  }) {
    final id = 'unix:${creds.host}|${creds.db}';
    if (!_instances.containsKey(id)) {
      final pool = pg.Pool.withEndpoints(
        [
          pg.Endpoint(
            host: creds.host,
            port: creds.port,
            database: creds.db,
            username: creds.username,
            password: creds.password,
            isUnixSocket: true,
          ),
        ],
        settings: pg.PoolSettings(
          maxConnectionCount: maxConnections,
          connectTimeout: connectTimeout,
          queryTimeout: queryTimeout,
          applicationName: applicationName,
        ),
      );
      _instances[id] = Stanza._(pool);
    }
    return _instances[id]!;
  }

  /// Create a Stanza instance from a connection URL string.
  ///
  /// The URL format is: `postgresql://user:password@host:port/dbname?sslmode=require`
  ///
  /// This supports all parameters recognized by the postgres v3 package,
  /// including `sslmode`, `application_name`, `connect_timeout`, and
  /// `query_timeout` as URL query parameters.
  /// Unrecognized query parameters (e.g. `channel_binding`) are stripped
  /// automatically for compatibility with various cloud providers.
  factory Stanza.url(String connectionUrl) {
    if (!_instances.containsKey(connectionUrl)) {
      final sanitized = _sanitizeConnectionUrl(connectionUrl);
      final pool = pg.Pool.withUrl(sanitized);
      _instances[connectionUrl] = Stanza._(pool);
    }
    return _instances[connectionUrl]!;
  }

  /// Retrieve a cached Stanza instance by its database reference.
  factory Stanza.getByDatabaseReference(
      String host, int port, String database) {
    final id = '$host:$port|$database';
    if (!_instances.containsKey(id)) {
      throw StanzaException(
          'No connection has been initialized for $host:$port|$database');
    }
    return _instances[id]!;
  }

  /// Execute a single query.
  ///
  /// The pool manages the connection lifecycle automatically.
  ///
  /// [overrideSafety]: Set to true to allow UPDATE/DELETE queries without WHERE clauses.
  Future<QueryResult<T>> execute<T>(Query query,
      {bool overrideSafety = false}) async {
    _checkSafety(query, overrideSafety);
    final result = await _pool.execute(
      pg.Sql.named(query.statement()),
      parameters: query.substitutionValues,
    );
    return _toQueryResult<T>(result, query);
  }

  /// Stream query results row by row.
  ///
  /// Uses postgres v3 prepared statements for true streaming — rows arrive
  /// one at a time without buffering the full result set in memory.
  ///
  /// ```dart
  /// await for (final row in stanza.stream<Animal>(selectQuery)) {
  ///   print(row.value?.name);
  /// }
  /// ```
  Stream<Result<T>> stream<T>(Query query) async* {
    final stmt = await _pool.prepare(pg.Sql.named(query.statement()));
    try {
      await for (final row in stmt.bind(query.substitutionValues)) {
        yield _toSingleResult<T>(row, query);
      }
    } finally {
      await stmt.dispose();
    }
  }

  /// Execute a raw SQL string.
  ///
  /// Use for DDL statements, migrations, or queries not expressible
  /// through the Stanza query builder.
  Future<pg.Result> rawExecute(String sql,
      {Map<String, dynamic>? parameters}) async {
    return _pool.execute(
      pg.Sql.named(sql),
      parameters: parameters,
    );
  }

  /// Execute multiple queries on the same connection.
  ///
  /// ```dart
  /// final result = await stanza.run((session) async {
  ///   await session.execute(insertQuery);
  ///   return session.execute<Animal>(selectQuery);
  /// });
  /// ```
  Future<T> run<T>(SessionBlock<T> block) async {
    return _pool.run((session) async {
      return block(StanzaSession._(session));
    });
  }

  /// Execute multiple queries within a database transaction.
  ///
  /// All queries in the block are executed atomically. If any query fails,
  /// the entire transaction is rolled back.
  ///
  /// ```dart
  /// final result = await stanza.runTransaction((session) async {
  ///   await session.execute(insertQuery);
  ///   return session.execute<Animal>(selectQuery);
  /// });
  /// ```
  Future<T> runTransaction<T>(SessionBlock<T> block) async {
    return _pool.runTx((session) async {
      return block(StanzaSession._(session));
    });
  }

  /// Close the connection pool and release all resources.
  Future<void> close() async {
    await _pool.close();
    // Remove from cache
    _instances.removeWhere((_, v) => identical(v, this));
  }

  /// List all currently cached instance IDs.
  static List<String> get listInstances => _instances.keys.toList();

  static final _instances = <String, Stanza>{};
}

/// Query parameters recognized by the postgres v3 package.
/// Unrecognized parameters (e.g. Neon's `channel_binding`) are stripped.
const _supportedUrlParams = {
  'application_name',
  'client_encoding',
  'connect_timeout',
  'dbname',
  'host',
  'password',
  'port',
  'replication',
  'sslcert',
  'sslkey',
  'sslmode',
  'sslrootcert',
  'user',
  'username',
  'query_timeout',
  'max_connection_age',
  'max_connection_count',
  'max_session_use',
  'max_query_count',
};

/// Strips query parameters not supported by the postgres v3 package.
String _sanitizeConnectionUrl(String url) {
  final uri = Uri.parse(url);
  if (uri.queryParameters.isEmpty) return url;
  final cleaned = Map.of(uri.queryParameters)
    ..removeWhere((key, _) => !_supportedUrlParams.contains(key));
  return uri.replace(queryParameters: cleaned).toString();
}

/// Checks that UPDATE/DELETE queries have WHERE clauses unless overridden.
void _checkSafety(Query query, bool overrideSafety) {
  if (overrideSafety) return;
  final isUnsafe = (query is DeleteQuery && query.whereClauses == null) ||
      (query is UpdateQuery && query.whereClauses == null);
  if (isUnsafe) {
    throw StanzaException(
      'This UPDATE or DELETE query has no WHERE clauses, which may be unsafe. '
      "Set 'overrideSafety: true' to execute it anyway.",
    );
  }
}

/// Converts a postgres v3 Result to a Stanza QueryResult.
QueryResult<T> _toQueryResult<T>(pg.Result result, Query query) {
  final rows = <Map<String, dynamic>>[];
  for (final row in result) {
    rows.add(row.toColumnMap());
  }
  return QueryResult<T>(rows, query.table);
}

/// Converts a single postgres v3 ResultRow to a Stanza Result.
Result<T> _toSingleResult<T>(pg.ResultRow row, Query query) {
  final map = row.toColumnMap();
  T? value;
  try {
    value = query.table.fromDb(map) as T;
  } catch (_) {
    value = null;
  }
  return Result<T>(value, map);
}
