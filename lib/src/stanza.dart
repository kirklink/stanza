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
    var queryResult = QueryResult<T>(result);
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
    final id = '${creds.host}:${creds.port}|${creds.db}';
    var connection = pg.PostgreSQLConnection(
        creds.host,
        creds.port,
        creds.db,
        username: creds.username,
        password: creds.password);
    if (!_connections.containsKey(id)) {
      _connections[id] = Stanza._(
        connection,
        pl.Pool(maxConnections, timeout: Duration(seconds: timeout))
      );
    }
    return _connections[id];
  }


  Future<QueryResult<T>> execute<T>(Query query, {bool autoRelease: true}) {
    return _pool.withResource(() async {
      await _connection.open();
      var result = await _connection.mappedResultsQuery(query.statement(), substitutionValues: query.     substitutionValues);
      if (autoRelease) {
        await _connection.close();
      }
      var queryResult = QueryResult<T>(result);
      return queryResult;
    });
    
  }

  Future<QueryResult<T>> executeTransaction<T>(QueryBlock queryBlock, {bool autoRelease: true}) {
    return _pool.withResource(() async {
      await _connection.open();
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


  static Map<String, Stanza> _connections = Map<String, Stanza>();
  // static pl.Pool _pool;
  // static PostgresCredentials _creds;


}
