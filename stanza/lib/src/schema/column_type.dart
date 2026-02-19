/// Represents a PostgreSQL column type with equivalence checking.
///
/// Handles mapping between Dart types and PostgreSQL types, and
/// normalizes type names from `information_schema` for comparison.
class ColumnType {
  final String value;

  const ColumnType(this.value);

  /// Infers a PostgreSQL type from a Dart type name.
  ///
  /// When [serial] is true, returns `serial` regardless of Dart type.
  static ColumnType fromDartType(String dartType, {bool serial = false}) {
    if (serial) return const ColumnType('serial');
    final base = dartType.replaceAll('?', '');
    switch (base) {
      case 'int':
        return const ColumnType('integer');
      case 'String':
        return const ColumnType('text');
      case 'bool':
        return const ColumnType('boolean');
      case 'double':
        return const ColumnType('double precision');
      case 'DateTime':
        return const ColumnType('timestamptz');
      default:
        return const ColumnType('text');
    }
  }

  /// Constructs a [ColumnType] from PostgreSQL `information_schema.columns.udt_name`.
  ///
  /// Maps internal UDT names (e.g. `int4`, `varchar`) to canonical PG type names.
  /// For `varchar`, uses [charMaxLength] to reconstruct `varchar(N)`.
  static ColumnType fromUdtName(String udtName, {String? charMaxLength}) {
    switch (udtName) {
      case 'int2':
        return const ColumnType('smallint');
      case 'int4':
        return const ColumnType('integer');
      case 'int8':
        return const ColumnType('bigint');
      case 'float4':
        return const ColumnType('real');
      case 'float8':
        return const ColumnType('double precision');
      case 'bool':
        return const ColumnType('boolean');
      case 'varchar':
        if (charMaxLength != null) {
          return ColumnType('varchar($charMaxLength)');
        }
        return const ColumnType('varchar');
      case 'text':
        return const ColumnType('text');
      case 'timestamptz':
        return const ColumnType('timestamptz');
      case 'timestamp':
        return const ColumnType('timestamp');
      case 'date':
        return const ColumnType('date');
      case 'jsonb':
        return const ColumnType('jsonb');
      case 'json':
        return const ColumnType('json');
      case 'uuid':
        return const ColumnType('uuid');
      case 'numeric':
        return const ColumnType('numeric');
      case 'bytea':
        return const ColumnType('bytea');
      default:
        return ColumnType(udtName);
    }
  }

  /// Checks if two column types are equivalent for diff purposes.
  ///
  /// `serial` is equivalent to `integer` because PostgreSQL stores serial
  /// columns as `integer` with a `nextval()` default — they appear as
  /// `integer` in `information_schema`.
  bool isEquivalentTo(ColumnType other) {
    if (value == other.value) return true;
    final a = _normalize(value);
    final b = _normalize(other.value);
    return a == b;
  }

  static String _normalize(String type) {
    switch (type) {
      case 'serial':
        return 'integer';
      case 'bigserial':
        return 'bigint';
      case 'smallserial':
        return 'smallint';
      default:
        return type;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is ColumnType && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}
