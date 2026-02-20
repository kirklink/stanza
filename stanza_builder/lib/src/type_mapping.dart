/// Maps Dart types to Postgres types and Stanza column class names.

/// Returns the Stanza typed column class for a given Dart type name.
String columnClassForDartType(String dartType) => switch (dartType) {
      'int' => 'IntColumn',
      'double' => 'DoubleColumn',
      'String' => 'StringColumn',
      'bool' => 'BoolColumn',
      'DateTime' => 'DateTimeColumn',
      _ => throw ArgumentError('Unsupported Dart type for column: $dartType'),
    };

/// Returns the Postgres column type for a given Dart type name.
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

/// Returns the Postgres serial type for auto-increment primary keys.
String serialTypeForDartType(String dartType) => switch (dartType) {
      'int' => 'serial',
      _ => throw ArgumentError(
          'Auto-increment only supported for int, got: $dartType'),
    };
