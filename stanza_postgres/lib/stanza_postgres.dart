/// PostgreSQL adapter for the Stanza ORM.
///
/// Provides the [Stanza] connection pool, schema introspection,
/// migration management, and CLI tooling for PostgreSQL databases.
///
/// ```dart
/// import 'package:stanza_postgres/stanza_postgres.dart';
///
/// final db = Stanza.url('postgresql://user:pass@host/dbname');
/// ```
library;

export 'src/postgres_database.dart';
export 'src/schema/pg_cli.dart';
export 'src/schema/pg_introspector.dart';
export 'src/schema/pg_migration_runner.dart';
export 'src/schema/pg_schema_manager.dart';
