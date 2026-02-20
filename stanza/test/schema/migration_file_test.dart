import 'package:stanza/schema.dart';
import 'package:test/test.dart';

void main() {
  group('MigrationFileWriter.generateFilename', () {
    test('formats timestamp correctly', () {
      final filename = MigrationFileWriter.generateFilename(
        now: DateTime.utc(2026, 2, 19, 14, 30, 22),
      );
      expect(filename, '20260219_143022.sql');
    });

    test('pads single-digit values', () {
      final filename = MigrationFileWriter.generateFilename(
        now: DateTime.utc(2026, 1, 5, 3, 7, 9),
      );
      expect(filename, '20260105_030709.sql');
    });
  });

  group('MigrationFileWriter.generate', () {
    test('wraps in BEGIN/COMMIT', () {
      final content = MigrationFileWriter.generate([]);
      expect(content, contains('BEGIN;'));
      expect(content, contains('COMMIT;'));
    });

    test('includes header comments', () {
      final content = MigrationFileWriter.generate([]);
      expect(content, contains('-- Stanza migration'));
      expect(content, contains('-- Generated at'));
    });

    test('includes SQL for operations', () {
      final content = MigrationFileWriter.generate([
        const AlterColumnType('users', 'data', 'jsonb'),
      ]);
      expect(
        content,
        contains('ALTER TABLE users ALTER COLUMN data TYPE jsonb;'),
      );
    });

    test('includes CreateTable DDL', () {
      final content = MigrationFileWriter.generate([
        CreateTable(SchemaTable(
          name: 'posts',
          columns: [
            const SchemaColumn(
              name: 'id',
              type: ColumnType('serial'),
              nullable: false,
            ),
            const SchemaColumn(name: 'title', type: ColumnType('text')),
          ],
          constraints: [
            const SchemaConstraint(
              name: 'posts_pkey',
              kind: ConstraintKind.primaryKey,
              columns: ['id'],
            ),
          ],
        )),
      ]);
      expect(content, contains('CREATE TABLE posts'));
      expect(content, contains('id serial NOT NULL'));
      expect(content, contains('CONSTRAINT posts_pkey PRIMARY KEY (id)'));
    });

    test('includes warning for SET NOT NULL', () {
      final content = MigrationFileWriter.generate([
        const AlterColumnNullability('users', 'name', false),
      ]);
      expect(content, contains('WARNING'));
      expect(content, contains('users.name'));
    });

    test('commented DROP COLUMN preserved', () {
      final content = MigrationFileWriter.generate([
        const DropColumn('users', 'old_col'),
      ]);
      expect(content, contains('-- SAFETY'));
      expect(content, contains('DROP COLUMN old_col'));
    });
  });
}
