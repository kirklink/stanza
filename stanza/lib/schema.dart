/// Schema management for Stanza — diffing, migration generation, and application.
///
/// Import this separately from `package:stanza/stanza.dart` when you need
/// schema management capabilities:
///
/// ```dart
/// import 'package:stanza/schema.dart';
/// ```
library schema;

export 'src/schema/column_type.dart';
export 'src/schema/schema_column.dart';
export 'src/schema/schema_constraint.dart';
export 'src/schema/schema_table.dart';
export 'src/schema/schema_diff.dart';
export 'src/schema/db_introspector.dart';
export 'src/schema/migration_file.dart';
export 'src/schema/migration_runner.dart';
export 'src/schema/schema_manager.dart';
export 'src/schema/stanza_cli.dart';
