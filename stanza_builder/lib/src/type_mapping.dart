/// Maps Dart types to Postgres types and Stanza column class names.
library;

/// Returns the Stanza typed column class for a given Dart type name.
///
/// Throws [ArgumentError] for unsupported types.
String columnClassForDartType(String dartType) => switch (dartType) {
      'int' => 'IntColumn',
      'double' => 'DoubleColumn',
      'String' => 'StringColumn',
      'bool' => 'BoolColumn',
      'DateTime' => 'DateTimeColumn',
      _ => throw ArgumentError('Unsupported Dart type for column: $dartType'),
    };

/// Returns the PostgreSQL column type for a given Dart type name.
///
/// If [length] is provided for `String` types, returns `varchar(N)`
/// instead of `text`. Throws [ArgumentError] for unsupported types.
String postgresTypeForDartType(String dartType, {int? length}) =>
    switch (dartType) {
      'int' => 'integer',
      'double' => 'double precision',
      'String' => length != null ? 'varchar($length)' : 'text',
      'bool' => 'boolean',
      'DateTime' => 'timestamptz',
      _ =>
        throw ArgumentError('Unsupported Dart type for Postgres: $dartType'),
    };

/// Returns the PostgreSQL serial type for auto-increment primary keys.
///
/// Only supports `int` (→ `serial`). Throws [ArgumentError] for other types.
String serialTypeForDartType(String dartType) => switch (dartType) {
      'int' => 'serial',
      _ => throw ArgumentError(
          'Auto-increment only supported for int, got: $dartType'),
    };
