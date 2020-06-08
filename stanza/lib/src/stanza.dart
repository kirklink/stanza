import 'package:pool/pool.dart' as pl;
import 'package:postgres/postgres.dart' as pg;
import 'package:stanza/src/connection.dart';
import 'package:stanza/src/postgres_credentials.dart';

import 'stanza_exception.dart';
export 'package:stanza/src/update/update_query.dart';
export 'package:stanza/src/delete/delete_query.dart';

/// The main class for creating, caching and using the Stanza database interface.
class Stanza {
  final PostgresCredentials _creds;
  final pl.Pool _pool;

  Stanza._(this._creds, this._pool);

  
  @deprecated
  factory Stanza(PostgresCredentials creds,
      {int maxConnections = 25, int timeout = 600}) {
    final id = '${creds.host}:${creds.port}|${creds.db}';
    if (!_connections.containsKey(id)) {
      _connections[id] = Stanza._(
          creds, pl.Pool(maxConnections, timeout: Duration(seconds: timeout)));
    }
    var cache = _connections[id];
    return cache;
  }

  factory Stanza.init(PostgresCredentials creds, {int maxConnections = 25, int timeout = 600}) {
    final id = '${creds.host}:${creds.port}|${creds.db}';
    if (!_connections.containsKey(id)) {
      _connections[id] = Stanza._(
          creds, pl.Pool(maxConnections, timeout: Duration(seconds: timeout)));
    }
    var cache = _connections[id];
    return cache;
  
  }

  factory Stanza.getbyDatabase(String host, int port, String database) {
    final id = '${host}:${port}|${database}';
    if (!_connections.containsKey(id)) {
      throw StanzaException('The connection has not been initialized for $host:$port|$database');
    } else {
      return _connections[id];
    }
  }

  factory Stanza.getByConnectionId(String id) {
    if (!_connections.containsKey(id)) {
      throw StanzaException('The connection has not been initialized for $id');
    } else {
      return _connections[id];
    }
  }

  /// Provides a databse connection using the Stanza instance's pooled connections.
  Future<StanzaConnection> connection() async {
    var connection = pg.PostgreSQLConnection(
        _creds.host, _creds.port, _creds.db,
        username: _creds.username, password: _creds.password);
    return StanzaConnection(_pool, connection);
  }

  static List<String> get listConnections =>_connections.keys.toList();

  static final Map<String, Stanza> _connections = Map<String, Stanza>();
}
