import 'package:stanza/src/schema/column_type.dart';
import 'package:stanza/src/schema/schema_column.dart';
import 'package:stanza/src/schema/schema_constraint.dart';
import 'package:stanza/src/schema/schema_table.dart';
import 'package:stanza/src/schema/schema_diff.dart';
import 'package:test/test.dart';

void main() {
  group('SchemaDiff.diff', () {
    test('new table produces CreateTable', () {
      final expected = SchemaTable(
        name: 'post',
        columns: [
          SchemaColumn(
            name: 'id',
            type: const ColumnType('serial'),
            nullable: false,
            isPrimaryKey: true,
            isSerial: true,
          ),
          SchemaColumn(
            name: 'title',
            type: const ColumnType('text'),
            nullable: false,
          ),
        ],
        constraints: [
          SchemaConstraint(
            name: 'post_pkey',
            kind: ConstraintKind.primaryKey,
            columns: ['id'],
          ),
        ],
      );

      final ops = SchemaDiff.diff(expected, null);
      expect(ops, hasLength(1));
      expect(ops.first, isA<CreateTable>());
    });

    test('identical tables produce no ops', () {
      final table = SchemaTable(
        name: 'post',
        columns: [
          SchemaColumn(
            name: 'id',
            type: const ColumnType('integer'),
            nullable: false,
          ),
          SchemaColumn(
            name: 'title',
            type: const ColumnType('text'),
            nullable: false,
          ),
        ],
        constraints: [
          SchemaConstraint(
            name: 'post_pkey',
            kind: ConstraintKind.primaryKey,
            columns: ['id'],
          ),
        ],
      );

      final ops = SchemaDiff.diff(table, table);
      expect(ops, isEmpty);
    });

    test('new column produces AddColumn', () {
      final expected = SchemaTable(
        name: 'post',
        columns: [
          SchemaColumn(
              name: 'id',
              type: const ColumnType('integer'),
              nullable: false),
          SchemaColumn(
              name: 'title',
              type: const ColumnType('text'),
              nullable: false),
          SchemaColumn(
              name: 'body',
              type: const ColumnType('text'),
              nullable: true),
        ],
      );

      final actual = SchemaTable(
        name: 'post',
        columns: [
          SchemaColumn(
              name: 'id',
              type: const ColumnType('integer'),
              nullable: false),
          SchemaColumn(
              name: 'title',
              type: const ColumnType('text'),
              nullable: false),
        ],
      );

      final ops = SchemaDiff.diff(expected, actual);
      expect(ops, hasLength(1));
      expect(ops.first, isA<AddColumn>());
      expect((ops.first as AddColumn).column.name, 'body');
    });

    test('type change produces AlterColumnType', () {
      final expected = SchemaTable(
        name: 'post',
        columns: [
          SchemaColumn(
              name: 'data',
              type: const ColumnType('jsonb'),
              nullable: true),
        ],
      );

      final actual = SchemaTable(
        name: 'post',
        columns: [
          SchemaColumn(
              name: 'data',
              type: const ColumnType('text'),
              nullable: true),
        ],
      );

      final ops = SchemaDiff.diff(expected, actual);
      expect(ops, hasLength(1));
      expect(ops.first, isA<AlterColumnType>());
      expect((ops.first as AlterColumnType).newType, 'jsonb');
    });

    test('serial and integer are equivalent (no type change)', () {
      final expected = SchemaTable(
        name: 'post',
        columns: [
          SchemaColumn(
            name: 'id',
            type: const ColumnType('serial'),
            nullable: false,
            isSerial: true,
          ),
        ],
      );

      final actual = SchemaTable(
        name: 'post',
        columns: [
          SchemaColumn(
            name: 'id',
            type: const ColumnType('integer'),
            nullable: false,
            isSerial: true,
          ),
        ],
      );

      final ops = SchemaDiff.diff(expected, actual);
      expect(ops, isEmpty);
    });

    test('nullability change produces AlterColumnNullability', () {
      final expected = SchemaTable(
        name: 'post',
        columns: [
          SchemaColumn(
              name: 'title',
              type: const ColumnType('text'),
              nullable: false),
        ],
      );

      final actual = SchemaTable(
        name: 'post',
        columns: [
          SchemaColumn(
              name: 'title',
              type: const ColumnType('text'),
              nullable: true),
        ],
      );

      final ops = SchemaDiff.diff(expected, actual);
      expect(ops, hasLength(1));
      expect(ops.first, isA<AlterColumnNullability>());
      expect((ops.first as AlterColumnNullability).nullable, isFalse);
    });

    test('default value change produces AlterColumnDefault', () {
      final expected = SchemaTable(
        name: 'post',
        columns: [
          SchemaColumn(
            name: 'status',
            type: const ColumnType('text'),
            nullable: false,
            defaultValue: "'active'",
          ),
        ],
      );

      final actual = SchemaTable(
        name: 'post',
        columns: [
          SchemaColumn(
            name: 'status',
            type: const ColumnType('text'),
            nullable: false,
          ),
        ],
      );

      final ops = SchemaDiff.diff(expected, actual);
      expect(ops, hasLength(1));
      expect(ops.first, isA<AlterColumnDefault>());
      expect((ops.first as AlterColumnDefault).newDefault, "'active'");
    });

    test('removed column produces DropColumn (commented)', () {
      final expected = SchemaTable(
        name: 'post',
        columns: [
          SchemaColumn(
              name: 'id',
              type: const ColumnType('integer'),
              nullable: false),
        ],
      );

      final actual = SchemaTable(
        name: 'post',
        columns: [
          SchemaColumn(
              name: 'id',
              type: const ColumnType('integer'),
              nullable: false),
          SchemaColumn(
              name: 'old_field',
              type: const ColumnType('text'),
              nullable: true),
        ],
      );

      final ops = SchemaDiff.diff(expected, actual);
      expect(ops, hasLength(1));
      expect(ops.first, isA<DropColumn>());
      final sql = ops.first.toSql();
      expect(sql, startsWith('-- SAFETY:'));
      expect(sql, contains('old_field'));
    });

    test('new constraint produces AddConstraint', () {
      final expected = SchemaTable(
        name: 'post',
        columns: [
          SchemaColumn(
              name: 'id',
              type: const ColumnType('integer'),
              nullable: false),
        ],
        constraints: [
          SchemaConstraint(
            name: 'post_pkey',
            kind: ConstraintKind.primaryKey,
            columns: ['id'],
          ),
        ],
      );

      final actual = SchemaTable(
        name: 'post',
        columns: [
          SchemaColumn(
              name: 'id',
              type: const ColumnType('integer'),
              nullable: false),
        ],
      );

      final ops = SchemaDiff.diff(expected, actual);
      expect(ops, hasLength(1));
      expect(ops.first, isA<AddConstraint>());
    });

    test('removed constraint produces DropConstraint', () {
      final expected = SchemaTable(
        name: 'post',
        columns: [
          SchemaColumn(
              name: 'id',
              type: const ColumnType('integer'),
              nullable: false),
        ],
      );

      final actual = SchemaTable(
        name: 'post',
        columns: [
          SchemaColumn(
              name: 'id',
              type: const ColumnType('integer'),
              nullable: false),
        ],
        constraints: [
          SchemaConstraint(
            name: 'post_old_idx',
            kind: ConstraintKind.unique,
            columns: ['id'],
          ),
        ],
      );

      final ops = SchemaDiff.diff(expected, actual);
      expect(ops, hasLength(1));
      expect(ops.first, isA<DropConstraint>());
    });

    test('multiple changes produce multiple ops', () {
      final expected = SchemaTable(
        name: 'post',
        columns: [
          SchemaColumn(
              name: 'id',
              type: const ColumnType('integer'),
              nullable: false),
          SchemaColumn(
              name: 'title',
              type: const ColumnType('varchar(255)'),
              nullable: false),
          SchemaColumn(
              name: 'body',
              type: const ColumnType('text'),
              nullable: true),
        ],
        constraints: [
          SchemaConstraint(
            name: 'post_pkey',
            kind: ConstraintKind.primaryKey,
            columns: ['id'],
          ),
        ],
      );

      final actual = SchemaTable(
        name: 'post',
        columns: [
          SchemaColumn(
              name: 'id',
              type: const ColumnType('integer'),
              nullable: false),
          SchemaColumn(
              name: 'title',
              type: const ColumnType('text'),
              nullable: true),
        ],
      );

      final ops = SchemaDiff.diff(expected, actual);
      // AddColumn(body), AlterColumnType(title), AlterColumnNullability(title), AddConstraint(pkey)
      expect(ops, hasLength(4));
      expect(ops.whereType<AddColumn>(), hasLength(1));
      expect(ops.whereType<AlterColumnType>(), hasLength(1));
      expect(ops.whereType<AlterColumnNullability>(), hasLength(1));
      expect(ops.whereType<AddConstraint>(), hasLength(1));
    });
  });

  group('SchemaDiffOp.toSql', () {
    test('CreateTable generates valid SQL', () {
      final table = SchemaTable(
        name: 'post',
        columns: [
          SchemaColumn(
            name: 'id',
            type: const ColumnType('serial'),
            nullable: false,
            isPrimaryKey: true,
            isSerial: true,
          ),
          SchemaColumn(
            name: 'title',
            type: const ColumnType('text'),
            nullable: false,
          ),
          SchemaColumn(
            name: 'status',
            type: const ColumnType('text'),
            nullable: false,
            defaultValue: "'draft'",
          ),
        ],
        constraints: [
          SchemaConstraint(
            name: 'post_pkey',
            kind: ConstraintKind.primaryKey,
            columns: ['id'],
          ),
        ],
      );

      final sql = CreateTable(table).toSql();
      expect(sql, contains('CREATE TABLE post'));
      expect(sql, contains('id serial NOT NULL'));
      expect(sql, contains('title text NOT NULL'));
      expect(sql, contains("status text NOT NULL DEFAULT 'draft'"));
      expect(sql, contains('CONSTRAINT post_pkey PRIMARY KEY (id)'));
    });

    test('AddColumn generates valid SQL', () {
      final sql = AddColumn(
        'post',
        SchemaColumn(
            name: 'body', type: const ColumnType('text'), nullable: true),
      ).toSql();
      expect(sql, equals('ALTER TABLE post ADD COLUMN body text;'));
    });

    test('AddColumn NOT NULL generates valid SQL', () {
      final sql = AddColumn(
        'post',
        SchemaColumn(
          name: 'title',
          type: const ColumnType('text'),
          nullable: false,
          defaultValue: "''",
        ),
      ).toSql();
      expect(sql,
          equals("ALTER TABLE post ADD COLUMN title text NOT NULL DEFAULT '';"));
    });

    test('AlterColumnType generates valid SQL', () {
      final sql = AlterColumnType('post', 'data', 'jsonb').toSql();
      expect(sql, equals('ALTER TABLE post ALTER COLUMN data TYPE jsonb;'));
    });

    test('AlterColumnNullability SET NOT NULL', () {
      final sql = AlterColumnNullability('post', 'title', false).toSql();
      expect(sql,
          equals('ALTER TABLE post ALTER COLUMN title SET NOT NULL;'));
    });

    test('AlterColumnNullability DROP NOT NULL', () {
      final sql = AlterColumnNullability('post', 'title', true).toSql();
      expect(sql,
          equals('ALTER TABLE post ALTER COLUMN title DROP NOT NULL;'));
    });

    test('AlterColumnDefault SET DEFAULT', () {
      final sql = AlterColumnDefault('post', 'status', "'active'").toSql();
      expect(sql,
          equals(
              "ALTER TABLE post ALTER COLUMN status SET DEFAULT 'active';"));
    });

    test('AlterColumnDefault DROP DEFAULT', () {
      final sql = AlterColumnDefault('post', 'status', null).toSql();
      expect(sql,
          equals('ALTER TABLE post ALTER COLUMN status DROP DEFAULT;'));
    });

    test('AddConstraint PK', () {
      final sql = AddConstraint(
        'post',
        SchemaConstraint(
          name: 'post_pkey',
          kind: ConstraintKind.primaryKey,
          columns: ['id'],
        ),
      ).toSql();
      expect(sql, contains('ADD CONSTRAINT post_pkey PRIMARY KEY (id)'));
    });

    test('AddConstraint UNIQUE', () {
      final sql = AddConstraint(
        'post',
        SchemaConstraint(
          name: 'post_email_key',
          kind: ConstraintKind.unique,
          columns: ['email'],
        ),
      ).toSql();
      expect(sql, contains('UNIQUE (email)'));
    });

    test('AddConstraint FK with ON DELETE', () {
      final sql = AddConstraint(
        'post',
        SchemaConstraint(
          name: 'post_author_id_fkey',
          kind: ConstraintKind.foreignKey,
          columns: ['author_id'],
          referencedTable: 'author',
          referencedColumn: 'id',
          onDelete: 'CASCADE',
        ),
      ).toSql();
      expect(sql, contains('FOREIGN KEY (author_id)'));
      expect(sql, contains('REFERENCES author (id)'));
      expect(sql, contains('ON DELETE CASCADE'));
    });

    test('DropColumn is commented out', () {
      final sql = DropColumn('post', 'old_col').toSql();
      expect(sql, startsWith('-- SAFETY:'));
      expect(sql, contains('DROP COLUMN old_col'));
    });

    test('DropConstraint generates valid SQL', () {
      final sql = DropConstraint('post', 'post_old_idx').toSql();
      expect(sql,
          equals('ALTER TABLE post DROP CONSTRAINT post_old_idx;'));
    });
  });

  group('SchemaTable helpers', () {
    test('columnByName finds existing column', () {
      final table = SchemaTable(
        name: 'post',
        columns: [
          SchemaColumn(
              name: 'id',
              type: const ColumnType('integer'),
              nullable: false),
        ],
      );
      expect(table.columnByName('id'), isNotNull);
      expect(table.columnByName('id')!.name, 'id');
    });

    test('columnByName returns null for missing column', () {
      final table = SchemaTable(name: 'post', columns: []);
      expect(table.columnByName('missing'), isNull);
    });

    test('constraint name conventions', () {
      final table = SchemaTable(name: 'post', columns: []);
      expect(table.primaryKeyConstraintName, 'post_pkey');
      expect(table.uniqueConstraintName('email'), 'post_email_key');
      expect(table.foreignKeyConstraintName('author_id'),
          'post_author_id_fkey');
    });
  });
}
