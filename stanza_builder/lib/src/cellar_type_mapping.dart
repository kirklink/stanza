/// Maps a Dart type name to the corresponding Cellar `FieldType` enum name.
///
/// Used by the code generator to produce `$cellarSchema` map entries
/// with the correct `'type'` value for `Collection.fromJson()`.
String cellarFieldTypeName(String dartType) => switch (dartType) {
      'String' => 'text',
      'int' => 'int',
      'double' => 'real',
      'bool' => 'bool',
      'DateTime' => 'datetime',
      _ => throw ArgumentError('Unsupported Dart type for Cellar: $dartType'),
    };
