/// SQLite adapter for Stanza ORM.
///
/// Provides [StanzaSqlite] database connection, schema introspection,
/// migration management, and a CLI for schema operations.
///
/// ```dart
/// import 'package:stanza_sqlite/stanza_sqlite.dart';
///
/// final db = StanzaSqlite.open('app.db');
/// final result = await db.execute(selectQuery);
/// ```
library;

export 'src/sqlite_database.dart';
export 'src/schema/sqlite_cli.dart';
export 'src/schema/sqlite_ddl.dart';
export 'src/schema/sqlite_introspector.dart';
export 'src/schema/sqlite_migration_runner.dart';
export 'src/schema/sqlite_schema_manager.dart';
