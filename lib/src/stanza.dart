import 'package:pool/pool.dart' as pl;
import 'package:postgres/postgres.dart' as pg;
import 'package:stanza/src/query.dart';
import 'package:stanza/src/postgres_credentials.dart';
import 'package:stanza/src/query_result.dart';
import 'package:stanza/src/table.dart';


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
  final PostgresCredentials creds;
  final pl.Pool pool;

  StanzaConnection(this.creds, this.pool);
}

class Stanza {

  pg.PostgreSQLConnection _connection;
  pl.Pool _pool;

  Stanza._(pg.PostgreSQLConnection this._connection, pl.Pool this._pool);

  factory Stanza(PostgresCredentials creds, {int maxConnections: 25, int timeout: 600}) {
    final id = '${creds.host}:${creds.port}|${creds.db}|${creds.username}';
    if (!_connections.containsKey(id)) {
      _connections[id] = StanzaConnection(
        creds, pl.Pool(maxConnections, timeout: Duration(seconds: timeout))
      );
    }
    var cache = _connections[id];
    var connection = pg.PostgreSQLConnection(
        cache.creds.host,
        cache.creds.port,
        cache.creds.db,
        username: cache.creds.username,
        password: cache.creds.password);
    return Stanza._(connection, cache.pool);
  }


  Future<QueryResult<T>> execute<T>(Query query, {bool autoRelease: true}) {
    return _pool.withResource(() async {
      if (_connection.isClosed) await _connection.open();
      var result = await _connection.mappedResultsQuery(query.statement(), substitutionValues: query.substitutionValues);
      if (autoRelease) {
        await _connection.close();
      }
      var queryResult = QueryResult<T>(result, query.table);
      return queryResult;
    });
    
  }

  Future<QueryResult<T>> executeTransaction<T>(QueryBlock queryBlock, {bool autoRelease: true}) {
    return _pool.withResource(() async {
      if (_connection.isClosed) await _connection.open();
      QueryResult<T> result = await _connection.transaction((ctx) async {
        return await queryBlock(_Transaction(ctx));
      });
      if (autoRelease) {
        await _connection.close();
      }
      return result;
    });
  }

  Future release() async {
    if (!_connection.isClosed) await _connection.close();
  } 


  static Map<String, StanzaConnection> _connections = Map<String, StanzaConnection>();

}
