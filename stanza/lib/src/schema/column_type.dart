/// Represents a PostgreSQL column type with normalization and equivalence checking.
///
/// Handles the mapping between Dart types, PostgreSQL types, and the
/// `information_schema` UDT names returned by database introspection.
class ColumnType {
  /// The PostgreSQL type name (e.g. `'integer'`, `'text'`, `'timestamptz'`).
  final String value;

  /// Creates a column type from a PostgreSQL type name.
  const ColumnType(this.value);

  /// Maps a Dart type name to the corresponding PostgreSQL type.
  ///
  /// If [serial] is true, returns `'serial'` (for auto-increment PKs).
  factory ColumnType.fromDartType(String dartType, {bool serial = false}) {
    if (serial) return const ColumnType('serial');

    final base = dartType.replaceAll('?', '');
    return switch (base) {
      'int' => const ColumnType('integer'),
      'String' => const ColumnType('text'),
      'bool' => const ColumnType('boolean'),
      'double' => const ColumnType('double precision'),
      'DateTime' => const ColumnType('timestamptz'),
      _ => const ColumnType('text'),
    };
  }

  /// Maps a PostgreSQL UDT name (from `information_schema`) to a canonical type.
  factory ColumnType.fromUdtName(String udtName, {String? charMaxLength}) {
    return switch (udtName) {
      'int4' => const ColumnType('integer'),
      'int2' => const ColumnType('smallint'),
      'int8' => const ColumnType('bigint'),
      'float4' => const ColumnType('real'),
      'float8' => const ColumnType('double precision'),
      'bool' => const ColumnType('boolean'),
      'varchar' => charMaxLength != null
          ? ColumnType('varchar($charMaxLength)')
          : const ColumnType('varchar'),
      'text' => const ColumnType('text'),
      'timestamptz' => const ColumnType('timestamptz'),
      'timestamp' => const ColumnType('timestamp'),
      'date' => const ColumnType('date'),
      'jsonb' => const ColumnType('jsonb'),
      'json' => const ColumnType('json'),
      'uuid' => const ColumnType('uuid'),
      'numeric' => const ColumnType('numeric'),
      'bytea' => const ColumnType('bytea'),
      _ => ColumnType(udtName),
    };
  }

  /// Whether this type is equivalent to [other] for diff purposes.
  ///
  /// Handles serial/integer equivalence — `serial` appears as `integer`
  /// in `information_schema`, so they're treated as equivalent.
  bool isEquivalentTo(ColumnType other) {
    if (value == other.value) return true;

    // Serial variants appear as their base integer type in information_schema
    const equivalences = {
      'serial': 'integer',
      'bigserial': 'bigint',
      'smallserial': 'smallint',
    };

    final normThis = equivalences[value] ?? value;
    final normOther = equivalences[other.value] ?? other.value;
    return normThis == normOther;
  }

  @override
  bool operator ==(Object other) =>
      other is ColumnType && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}
