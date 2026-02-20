/// Abstract database adapter interface.
///
/// Adapters (e.g. `stanza_postgres`, `stanza_sqlite`) implement this
/// to provide driver-specific connection and query execution.
///
/// The core query builders, table accessors, and expressions work against
/// this interface — they never depend on a specific driver package.
library;

import 'parameter.dart';
import 'query.dart';
import 'result.dart';
import 'table.dart';

/// Callback type for session-based execution (transactions, multi-query).
typedef AdapterSessionBlock<T> = Future<T> Function(SessionAdapter session);

/// A database adapter that can execute queries and manage transactions.
///
/// Implementations wrap a specific driver (postgres, sqlite3, etc.) and handle:
/// - Query execution with parameterized SQL
/// - Transaction management
/// - Parameter format differences between drivers
abstract class DatabaseAdapter {
  /// Executes a typed query and returns mapped results.
  Future<QueryResult<T>> execute<T, D extends TableDescriptor<T>>(
    Query<T, D> query,
  );

  /// Executes raw SQL with optional named parameters.
  Future<QueryResult<Never>> rawExecute(
    String sql, {
    Map<String, dynamic>? parameters,
  });

  /// Runs multiple queries on a single connection (no transaction).
  Future<T> run<T>(AdapterSessionBlock<T> block);

  /// Runs queries in a transaction. Rolls back on error.
  Future<T> transaction<T>(AdapterSessionBlock<T> block);

  /// Executes raw SQL and maps results using a custom function.
  Future<List<R>> rawQuery<R>(
    String sql, {
    Map<String, dynamic>? parameters,
    required R Function(Map<String, dynamic> row) mapper,
  });

  /// Creates a [ParameterCollector] configured for this adapter's
  /// parameter placeholder format (e.g. `@p0` for Postgres, `:p0` for SQLite).
  ParameterCollector createParameterCollector();

  /// Closes the database connection.
  Future<void> close();
}

/// A single database session for use within [DatabaseAdapter.run] and
/// [DatabaseAdapter.transaction] blocks.
///
/// Provides the same query execution API as [DatabaseAdapter] but operates on
/// a single connection, ensuring sequential execution within the session.
abstract class SessionAdapter {
  /// Executes a typed query and returns mapped results.
  Future<QueryResult<T>> execute<T, D extends TableDescriptor<T>>(
    Query<T, D> query,
  );

  /// Executes raw SQL with optional named parameters.
  Future<QueryResult<Never>> rawExecute(
    String sql, {
    Map<String, dynamic>? parameters,
  });

  /// Executes raw SQL and maps results using a custom function.
  Future<List<R>> rawQuery<R>(
    String sql, {
    Map<String, dynamic>? parameters,
    required R Function(Map<String, dynamic> row) mapper,
  });
}
