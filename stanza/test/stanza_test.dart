import 'package:test/test.dart';
import 'package:stanza/stanza.dart';

void main() {
  tearDown(() async {
    // Clean up cached instances after each test
    // Can't close pools created with fake creds, but the cache is per-process
  });

  group('Stanza.tcp', () {
    test('accepts connection config parameters', () {
      final creds = PostgresCredentials('localhost', 5432, 'testdb', 'user', 'pass');
      // Should not throw — pool is created lazily, no actual connection attempted
      final stanza = Stanza.tcp(
        creds,
        maxConnections: 5,
        sslMode: SslMode.disable,
        connectTimeout: Duration(seconds: 10),
        queryTimeout: Duration(seconds: 30),
        applicationName: 'stanza-test',
      );
      expect(stanza, isNotNull);
    });

    test('caches instances by host:port|db', () {
      final creds = PostgresCredentials('localhost', 5433, 'cachetest', 'u', 'p');
      final a = Stanza.tcp(creds);
      final b = Stanza.tcp(creds);
      expect(identical(a, b), isTrue);
    });
  });

  group('Stanza.unix', () {
    test('accepts connection config parameters', () {
      final creds = PostgresCredentials('/var/run/postgresql', 5432, 'testdb', 'user', 'pass');
      final stanza = Stanza.unix(
        creds,
        maxConnections: 5,
        connectTimeout: Duration(seconds: 10),
        queryTimeout: Duration(seconds: 30),
        applicationName: 'stanza-test',
      );
      expect(stanza, isNotNull);
    });
  });

  group('SslMode', () {
    test('SslMode is exported from stanza', () {
      // Verify the re-export works — users can reference SslMode
      // without importing package:postgres directly
      expect(SslMode.disable, isNotNull);
      expect(SslMode.require, isNotNull);
      expect(SslMode.verifyFull, isNotNull);
    });
  });
}
