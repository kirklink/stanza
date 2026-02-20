import 'schema_diff.dart';

/// Generates timestamped migration SQL files from schema diff operations.
class MigrationFileWriter {
  /// Generates a migration filename from a timestamp.
  ///
  /// Format: `YYYYMMDD_HHMMSS.sql`
  static String generateFilename({DateTime? now}) {
    final ts = now ?? DateTime.now().toUtc();
    final y = ts.year.toString().padLeft(4, '0');
    final m = ts.month.toString().padLeft(2, '0');
    final d = ts.day.toString().padLeft(2, '0');
    final h = ts.hour.toString().padLeft(2, '0');
    final min = ts.minute.toString().padLeft(2, '0');
    final s = ts.second.toString().padLeft(2, '0');
    return '$y$m${d}_$h$min$s.sql';
  }

  /// Generates the full SQL migration file content.
  ///
  /// Wraps operations in BEGIN/COMMIT and includes header comments.
  static String generate(List<SchemaDiffOp> ops) {
    final buf = StringBuffer();
    final now = DateTime.now().toUtc().toIso8601String();

    buf.writeln('-- Stanza migration');
    buf.writeln('-- Generated at $now');
    buf.writeln();
    buf.writeln('BEGIN;');
    buf.writeln();

    // Add warnings for SET NOT NULL operations
    for (final op in ops) {
      if (op is AlterColumnNullability && !op.nullable) {
        buf.writeln(
          '-- WARNING: Setting NOT NULL on ${op.tableName}.${op.columnName}. '
          'Ensure existing rows have values or add a DEFAULT first.',
        );
      }
    }

    for (final op in ops) {
      buf.writeln(op.toSql());
      buf.writeln();
    }

    buf.writeln('COMMIT;');
    return buf.toString();
  }
}
