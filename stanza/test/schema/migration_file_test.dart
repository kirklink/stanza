import 'package:stanza/src/schema/column_type.dart';
import 'package:stanza/src/schema/schema_column.dart';
import 'package:stanza/src/schema/schema_constraint.dart';
import 'package:stanza/src/schema/schema_diff.dart';
import 'package:stanza/src/schema/schema_table.dart';
import 'package:stanza/src/schema/migration_file.dart';
import 'package:test/test.dart';

void main() {
  final writer = const MigrationFileWriter();

  group('MigrationFileWriter.generateFilename', () {
    test('produces timestamped filename', () {
      final now = DateTime(2026, 2, 19, 14, 30, 22);
      final filename = writer.generateFilename(now: now);
      expect(filename, '20260219_143022.sql');
    });

    test('pads single-digit values', () {
      final now = DateTime(2026, 1, 5, 3, 7, 9);
      final filename = writer.generateFilename(now: now);
      expect(filename, '20260105_030709.sql');
    });
  });

  group('MigrationFileWriter.generate', () {
    test('wraps in BEGIN/COMMIT', () {
      final ops = [
        AddColumn(
          'post',
          SchemaColumn(
              name: 'body', type: const ColumnType('text'), nullable: true),
        ),
      ];
      final content = writer.generate(ops);
      expect(content, contains('BEGIN;'));
      expect(content, contains('COMMIT;'));
    });

    test('includes header comment', () {
      final ops = [
        AddColumn(
          'post',
          SchemaColumn(
              name: 'body', type: const ColumnType('text'), nullable: true),
        ),
      ];
      final content = writer.generate(ops);
      expect(content, contains('-- Stanza migration'));
      expect(content, contains('-- Generated at'));
    });

    test('includes SQL for each op', () {
      final ops = [
        AddColumn(
          'post',
          SchemaColumn(
              name: 'body', type: const ColumnType('text'), nullable: true),
        ),
        AlterColumnNullability('post', 'title', false),
      ];
      final content = writer.generate(ops);
      expect(content, contains('ALTER TABLE post ADD COLUMN body text;'));
      expect(content, contains('SET NOT NULL'));
    });

    test('adds warning for SET NOT NULL', () {
      final ops = [
        AlterColumnNullability('post', 'title', false),
      ];
      final content = writer.generate(ops);
      expect(content, contains('-- WARNING:'));
      expect(content, contains('Setting NOT NULL'));
    });

    test('CreateTable produces full DDL', () {
      final table = SchemaTable(
        name: 'author',
        columns: [
          SchemaColumn(
            name: 'id',
            type: const ColumnType('serial'),
            nullable: false,
            isPrimaryKey: true,
            isSerial: true,
          ),
          SchemaColumn(
            name: 'name',
            type: const ColumnType('text'),
            nullable: false,
          ),
        ],
        constraints: [
          SchemaConstraint(
            name: 'author_pkey',
            kind: ConstraintKind.primaryKey,
            columns: ['id'],
          ),
        ],
      );
      final content = writer.generate([CreateTable(table)]);
      expect(content, contains('CREATE TABLE author'));
      expect(content, contains('id serial NOT NULL'));
      expect(content, contains('name text NOT NULL'));
      expect(content, contains('CONSTRAINT author_pkey PRIMARY KEY (id)'));
    });

    test('DropColumn is commented out', () {
      final ops = [DropColumn('post', 'old_col')];
      final content = writer.generate(ops);
      expect(content, contains('-- SAFETY:'));
      expect(content, contains('DROP COLUMN old_col'));
    });
  });
}
