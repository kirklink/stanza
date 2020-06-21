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
  final bool _isUnix;

  Stanza._(this._creds, this._pool, this._isUnix);

  
  @deprecated
  factory Stanza(PostgresCredentials creds,
      {int maxConnections = 25, int timeout = 600}) {
    final id = '${creds.host}:${creds.port}|${creds.db}';
    if (!_instances.containsKey(id)) {
      _instances[id] = Stanza._(
          creds, pl.Pool(maxConnections, timeout: Duration(seconds: timeout)), false);
    }
    var cache = _instances[id];
    return cache;
  }

  @deprecated
  factory Stanza.init(PostgresCredentials creds, {int maxConnections = 25, int timeout = 600}) {
    final id = '${creds.host}:${creds.port}|${creds.db}';
    if (!_instances.containsKey(id)) {
      _instances[id] = Stanza._(
          creds, pl.Pool(maxConnections, timeout: Duration(seconds: timeout)), false);
    }
    var cache = _instances[id];
    return cache;
  }

  factory Stanza.tcp(PostgresCredentials creds, {int maxConnections = 25, int timeout = 600}) {
    final id = '${creds.host}:${creds.port}|${creds.db}';
    if (!_instances.containsKey(id)) {
      _instances[id] = Stanza._(
          creds, pl.Pool(maxConnections, timeout: Duration(seconds: timeout)), false);
    }
    return _instances[id];
  }

  factory Stanza.unix(PostgresCredentials creds, {int maxConnections = 25, int timeout = 600}) {
    final id = '${creds.host}:${creds.port}|${creds.db}';
    if (!_instances.containsKey(id)) {
      _instances[id] = Stanza._(
          creds, pl.Pool(maxConnections, timeout: Duration(seconds: timeout)), true);
    }
    return _instances[id];
  }

  factory Stanza.getbyDatabaseReference(String host, int port, String database) {
    final id = '${host}:${port}|${database}';
    if (!_instances.containsKey(id)) {
      throw StanzaException('The connection has not been initialized for $host:$port|$database');
    } else {
      return _instances[id];
    }
  }

  factory Stanza.getByInstanceId(String id) {
    if (!_instances.containsKey(id)) {
      throw StanzaException('The connection has not been initialized for $id');
    } else {
      return _instances[id];
    }
  }

  /// Provides a databse connection using the Stanza instance's pooled connections.
  Future<StanzaConnection> connection() async {
    final connection = pg.PostgreSQLConnection(
        _creds.host, _creds.port, _creds.db,
        username: _creds.username, password: _creds.password, isUnixSocket: _isUnix);
    print(connection.isUnixSocket);
    print(connection.isClosed);
    print('WAITING FOR POOL RESOURCE');
    final resource = await _pool.request();
    print(resource.hashCode);
    print('WAITING FOR CONNECTION TO OPEN');
    await connection.open();
    print(connection.isClosed);
    return StanzaConnection(resource, connection);
  }

  static List<String> get listInstances =>_instances.keys.toList();

  static final _instances = <String, Stanza>{};
}
