/// Schema management, diffing, and migration support for Stanza.
///
/// Import this library for schema-only operations (CLI tools, migration scripts).
/// For full ORM functionality, use `package:stanza/stanza.dart` instead.
library;

export 'src/schema/column_type.dart';
export 'src/schema/migration_file.dart';
export 'src/schema/schema_column.dart';
export 'src/schema/schema_constraint.dart';
export 'src/schema/schema_diff.dart';
export 'src/schema/schema_table.dart';
