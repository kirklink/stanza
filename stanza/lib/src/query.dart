import 'parameter.dart';
import 'table.dart';

/// Base class for all query types.
///
/// Provides SQL generation and parameter collection.
abstract class Query<T, D extends TableDescriptor<T>> {
  /// The table descriptor this query operates on.
  final D table;

  /// Creates a query bound to the given table descriptor.
  Query(this.table);

  /// Generates the SQL string, collecting parameterized values in [params].
  String toSql(ParameterCollector params);

  /// Convenience: generates SQL and returns both the statement and parameters.
  ({String sql, Map<String, dynamic> parameters}) build() {
    final params = ParameterCollector();
    final sql = toSql(params);
    return (sql: sql, parameters: params.values);
  }
}
