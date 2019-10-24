class PostgresCredentials {
  final String host;
  final int port;
  final String db;
  final String username;
  final String password;

  PostgresCredentials(
    this.host,
    this.port,
    this.db,
    this.username,
    this.password
  );

}