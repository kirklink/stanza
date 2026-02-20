/// Collects parameterized values for safe SQL generation.
///
/// Every user-provided value is assigned a unique parameter name (`p0`, `p1`, etc.)
/// and stored for binding at execution time. This prevents SQL injection.
///
/// The [placeholderPrefix] controls the SQL placeholder format:
/// - `@` (default) produces `@p0`, `@p1` — used by PostgreSQL
/// - `:` produces `:p0`, `:p1` — used by SQLite
class ParameterCollector {
  final Map<String, dynamic> _values = {};
  final String _placeholderPrefix;
  int _counter = 0;

  /// Creates a parameter collector.
  ///
  /// The [placeholderPrefix] determines the SQL placeholder format.
  /// Defaults to `@` for PostgreSQL compatibility.
  ParameterCollector({String placeholderPrefix = '@'})
      : _placeholderPrefix = placeholderPrefix;

  /// Registers a value and returns its parameter placeholder (e.g. `@p0`).
  String add(Object? value) {
    final name = 'p${_counter++}';
    _values[name] = value;
    return '$_placeholderPrefix$name';
  }

  /// The collected parameter name-value pairs for query execution.
  ///
  /// Keys are unprefixed (e.g. `p0`, `p1`). The adapter is responsible
  /// for any key-format transformation needed by the driver.
  Map<String, dynamic> get values => Map.unmodifiable(_values);

  /// Number of parameters collected.
  int get length => _values.length;
}
