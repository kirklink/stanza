import 'package:pool/pool.dart' as pl;
import 'package:postgres/postgres.dart' as pg;
import 'package:stanza/src/query.dart';
import 'package:stanza/src/postgres_credentials.dart';
import 'package:stanza/src/query_result.dart';


class _Transaction {
  final pg.PostgreSQLExecutionContext ctx;

  _Transaction(this.ctx);

  Future<QueryResult<T>> execute<T>(Query query) async {
    var result = await ctx.mappedResultsQuery(query.statement(), substitutionValues: query.substitutionValues);
    var queryResult = QueryResult<T>(result, query.table);
    return queryResult;
  }
}

typedef Future<QueryResult<T>> QueryBlock<T>(_Transaction tx);

class StanzaConnection {
  
  pl.Pool _pool;
  pl.PoolResource _resource;
  pg.PostgreSQLConnection _connection;

  StanzaConnection(this._pool, this._connection);

  Future<QueryResult<T>> execute<T>(Query query, {bool autoClose: true}) async {
    if (_resource == null) _resource = await _pool.request();
    if (_connection.isClosed) await _connection.open();
    var result = await _connection.mappedResultsQuery(query.statement(), substitutionValues: query.substitutionValues);
    if (autoClose) {
      await _connection.close();
      _resource.release();
    }
    var queryResult = QueryResult<T>(result, query.table);
    return queryResult;
  }

  Future<QueryResult<T>> executeTransaction<T>(QueryBlock queryBlock, {bool autoClose: true}) async {
    if (_resource == null) _resource = await _pool.request();
    if (_connection.isClosed) await _connection.open();
    QueryResult<T> result = await _connection.transaction((ctx) async {
      return await queryBlock(_Transaction(ctx));
    });
    if (autoClose) {
      await _connection.close();
      _resource.release();
    }
    return result;
  }

  Future close() async {
    if (!_connection.isClosed) await _connection.close();
    _resource.release();
  } 
}

class Stanza {

  final PostgresCredentials _creds;
  final pl.Pool _pool;

  Stanza._(this._creds, this._pool);

  factory Stanza(PostgresCredentials creds, {int maxConnections: 25, int timeout: 600}) {
    final id = '${creds.host}:${creds.port}|${creds.db}|${creds.username}';
    if (!_connections.containsKey(id)) {
      _connections[id] = Stanza._(
        creds, pl.Pool(maxConnections, timeout: Duration(seconds: timeout))
      );
    }
    var cache = _connections[id];
    return cache;
  }

  Future<StanzaConnection> connection() async {
    var connection = pg.PostgreSQLConnection(
        _creds.host,
        _creds.port,
        _creds.db,
        username: _creds.username,
        password: _creds.password);
    return StanzaConnection(_pool, connection);
  }

  static Map<String, Stanza> _connections = Map<String, Stanza>();

}
