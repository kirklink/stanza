import 'package:stanza/src/schema/column_type.dart';
import 'package:test/test.dart';

void main() {
  group('ColumnType.fromDartType', () {
    test('int maps to integer', () {
      expect(ColumnType.fromDartType('int').value, 'integer');
    });

    test('int? maps to integer', () {
      expect(ColumnType.fromDartType('int?').value, 'integer');
    });

    test('String maps to text', () {
      expect(ColumnType.fromDartType('String').value, 'text');
    });

    test('bool maps to boolean', () {
      expect(ColumnType.fromDartType('bool').value, 'boolean');
    });

    test('double maps to double precision', () {
      expect(ColumnType.fromDartType('double').value, 'double precision');
    });

    test('DateTime maps to timestamptz', () {
      expect(ColumnType.fromDartType('DateTime').value, 'timestamptz');
    });

    test('serial overrides Dart type', () {
      expect(ColumnType.fromDartType('int', serial: true).value, 'serial');
    });

    test('unknown type defaults to text', () {
      expect(ColumnType.fromDartType('CustomClass').value, 'text');
    });
  });

  group('ColumnType.fromUdtName', () {
    test('int4 maps to integer', () {
      expect(ColumnType.fromUdtName('int4').value, 'integer');
    });

    test('int8 maps to bigint', () {
      expect(ColumnType.fromUdtName('int8').value, 'bigint');
    });

    test('float8 maps to double precision', () {
      expect(ColumnType.fromUdtName('float8').value, 'double precision');
    });

    test('bool maps to boolean', () {
      expect(ColumnType.fromUdtName('bool').value, 'boolean');
    });

    test('varchar with length', () {
      expect(
          ColumnType.fromUdtName('varchar', charMaxLength: '255').value,
          'varchar(255)');
    });

    test('varchar without length', () {
      expect(ColumnType.fromUdtName('varchar').value, 'varchar');
    });

    test('timestamptz passes through', () {
      expect(ColumnType.fromUdtName('timestamptz').value, 'timestamptz');
    });

    test('jsonb passes through', () {
      expect(ColumnType.fromUdtName('jsonb').value, 'jsonb');
    });

    test('uuid passes through', () {
      expect(ColumnType.fromUdtName('uuid').value, 'uuid');
    });

    test('unknown udt passes through', () {
      expect(ColumnType.fromUdtName('citext').value, 'citext');
    });
  });

  group('ColumnType.isEquivalentTo', () {
    test('same type is equivalent', () {
      expect(
          const ColumnType('integer')
              .isEquivalentTo(const ColumnType('integer')),
          isTrue);
    });

    test('serial is equivalent to integer', () {
      expect(
          const ColumnType('serial')
              .isEquivalentTo(const ColumnType('integer')),
          isTrue);
    });

    test('integer is equivalent to serial', () {
      expect(
          const ColumnType('integer')
              .isEquivalentTo(const ColumnType('serial')),
          isTrue);
    });

    test('bigserial is equivalent to bigint', () {
      expect(
          const ColumnType('bigserial')
              .isEquivalentTo(const ColumnType('bigint')),
          isTrue);
    });

    test('text is not equivalent to integer', () {
      expect(
          const ColumnType('text')
              .isEquivalentTo(const ColumnType('integer')),
          isFalse);
    });
  });

  group('ColumnType equality', () {
    test('equal types', () {
      expect(const ColumnType('text'), equals(const ColumnType('text')));
    });

    test('different types', () {
      expect(const ColumnType('text'),
          isNot(equals(const ColumnType('integer'))));
    });
  });
}
