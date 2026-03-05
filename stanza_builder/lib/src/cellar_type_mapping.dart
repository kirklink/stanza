/// Maps a Dart type name to the corresponding `CellarField` named constructor.
///
/// Used by the code generator to produce `CellarCollection` constants
/// with the correct field constructor calls.
String cellarFieldConstructor(String dartType) => switch (dartType) {
      'String' => 'CellarField.text',
      'int' => 'CellarField.int',
      'double' => 'CellarField.real',
      'bool' => 'CellarField.bool',
      'DateTime' => 'CellarField.datetime',
      _ => throw ArgumentError('Unsupported Dart type for Cellar: $dartType'),
    };
