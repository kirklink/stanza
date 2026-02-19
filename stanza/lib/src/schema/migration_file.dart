import 'schema_diff.dart';

/// Generates timestamped migration SQL files from a list of [SchemaDiffOp]s.
class MigrationFileWriter {
  const MigrationFileWriter();

  /// Generates a migration filename based on the current timestamp.
  ///
  /// Format: `YYYYMMDD_HHMMSS.sql`
  String generateFilename({DateTime? now}) {
    final ts = now ?? DateTime.now();
    final y = ts.year.toString().padLeft(4, '0');
    final m = ts.month.toString().padLeft(2, '0');
    final d = ts.day.toString().padLeft(2, '0');
    final h = ts.hour.toString().padLeft(2, '0');
    final min = ts.minute.toString().padLeft(2, '0');
    final s = ts.second.toString().padLeft(2, '0');
    return '$y$m${d}_$h$min$s.sql';
  }

  /// Generates the full SQL content for a migration file.
  ///
  /// Wraps the SQL in a transaction (`BEGIN`/`COMMIT`) with a header comment.
  /// `SET NOT NULL` without a corresponding default value gets a warning comment.
  String generate(List<SchemaDiffOp> ops) {
    final buf = StringBuffer();
    buf.writeln('-- Stanza migration');
    buf.writeln('-- Generated at ${DateTime.now().toUtc().toIso8601String()}');
    buf.writeln();
    buf.writeln('BEGIN;');
    buf.writeln();

    for (final op in ops) {
      // Add warning comment for SET NOT NULL without a default
      if (op is AlterColumnNullability && !op.nullable) {
        buf.writeln(
            '-- WARNING: Setting NOT NULL on existing column "${op.columnName}".');
        buf.writeln(
            '-- Ensure all existing rows have a value or add a DEFAULT first.');
      }

      buf.writeln(op.toSql());
      buf.writeln();
    }

    buf.writeln('COMMIT;');
    return buf.toString();
  }
}
