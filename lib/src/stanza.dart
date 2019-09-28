import 'package:pool/pool.dart' as pl;
import 'package:postgres/postgres.dart' as pg;
import 'package:stanza/src/exception.dart';
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


class Stanza {

pg.PostgreSQLConnection _connection;

Future<QueryResult<T>> execute<T>(Query query, {bool autoRelease: true}) {
  return _pool.withResource(() async {
    _connection = pg.PostgreSQLConnection(
      _creds.host,
      _creds.port,
      _creds.db,
      username: _creds.username,
      password: _creds.password
    );
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
    _connection = pg.PostgreSQLConnection(
      _creds.host,
      _creds.port,
      _creds.db,
      username: _creds.username,
      password: _creds.password
    );
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

Stanza._();

factory Stanza.connect() {
  if (_creds == null) throw QueryException('Database has not been initialized.');
  return Stanza._();
}

static void initialize(PostgresCredentials creds, {int maxConnections: 100, int timeout: 600}) {
  _creds = creds;
  _pool = pl.Pool(maxConnections, timeout: Duration(seconds: timeout));
}

static pl.Pool _pool;
static PostgresCredentials _creds;


}
