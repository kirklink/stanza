import 'package:pool/pool.dart' as pl;
import 'package:postgres/postgres.dart' as pg;
import 'package:stanza/src/delete/delete_query.dart';
import 'package:stanza/src/query.dart';
import 'package:stanza/src/query_result.dart';
import 'package:stanza/src/stanza_exception.dart';
import 'package:stanza/src/update/update_query.dart';

typedef Future<QueryResult<T>> QueryBlock<T>(_Transaction tx);

class _Transaction {
  final pg.PostgreSQLExecutionContext ctx;

  _Transaction(this.ctx);

  Future<QueryResult<T>> execute<T>(Query query,
      {bool overrideSafety = false}) async {
    if ((query is DeleteQuery && query.whereClauses == null) ||
        (query is UpdateQuery && query.whereClauses == null)) {
      if (!overrideSafety) {
        final message = '''
          The update or delete query does not have any where clauses, which may make it
          unsafe. If you want to use this query, set 'overrideSafety' to true in the
          execute function call.
        ''';
        throw StanzaException(message);
      }
    }
    var result = await ctx.mappedResultsQuery(query.statement(),
        substitutionValues: query.substitutionValues);
    var queryResult = QueryResult<T>(result, query.table);
    return queryResult;
  }
}

/// A database connection that in one of the pooled connections from a Stanza instance.
class StanzaConnection {
  pl.Pool _pool;
  pl.PoolResource _resource;
  pg.PostgreSQLConnection _connection;

  StanzaConnection(this._pool, this._connection);

  /// Executes a [Query].
  ///
  /// [autoClose]: Can be set to false to keep the connection alive. Closing the connection later
  /// is the responsibility of the user.
  /// [overrideSafety]: Can be set to true to allow an update or delete query to be executed, which
  /// might otherwise be unsafe.
  Future<QueryResult<T>> execute<T>(Query query,
      {bool autoClose = true, bool overrideSafety = false}) async {
    if ((query is DeleteQuery && query.whereClauses == null) ||
        (query is UpdateQuery && query.whereClauses == null)) {
      if (!overrideSafety) {
        final message = '''
          The update or delete query does not have any where clauses, which may make it
          unsafe. If you want to use this query, set 'overrideSafety' to true in the
          execute function call.
        ''';
        throw StanzaException(message);
      }
    }
    _resource ??= await _pool.request();
    if (_connection.isClosed) {
      await _connection.open();
    }
    var result = await _connection.mappedResultsQuery(query.statement(),
        substitutionValues: query.substitutionValues);
    if (autoClose) {
      await _connection.close();
      _resource.release();
    }
    var queryResult = QueryResult<T>(result, query.table);
    return queryResult;
  }

  /// Executes two or more [Query] within a database transaction.
  ///
  /// [executeTransaction] provides a [QueryBlock] to which several queries can be attached
  /// and executed within a single database transaction, returning a single result.
  Future<QueryResult<T>> executeTransaction<T>(QueryBlock<T> queryBlock,
      {bool autoClose = true, bool overrideSafety = false}) async {
    _resource ??= await _pool.request();
    if (_connection.isClosed) await _connection.open();
    final result = await _connection.transaction((ctx) async {
      return await queryBlock(_Transaction(ctx));
    }) as QueryResult<T>;
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
