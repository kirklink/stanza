/// Collects parameterized values for safe SQL generation.
///
/// Every user-provided value is assigned a unique parameter name (`@p0`, `@p1`, etc.)
/// and stored for binding at execution time. This prevents SQL injection.
class ParameterCollector {
  final Map<String, dynamic> _values = {};
  int _counter = 0;

  /// Registers a value and returns its parameter placeholder (e.g. `@p0`).
  String add(Object? value) {
    final name = 'p${_counter++}';
    _values[name] = value;
    return '@$name';
  }

  /// The collected parameter name-value pairs for query execution.
  Map<String, dynamic> get values => Map.unmodifiable(_values);

  /// Number of parameters collected.
  int get length => _values.length;
}
