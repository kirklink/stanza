import 'package:stanza/schema.dart';
import 'package:test/test.dart';

void main() {
  group('fromDartType', () {
    test('int → integer', () {
      expect(ColumnType.fromDartType('int').value, 'integer');
    });

    test('String → text', () {
      expect(ColumnType.fromDartType('String').value, 'text');
    });

    test('bool → boolean', () {
      expect(ColumnType.fromDartType('bool').value, 'boolean');
    });

    test('double → double precision', () {
      expect(ColumnType.fromDartType('double').value, 'double precision');
    });

    test('DateTime → timestamptz', () {
      expect(ColumnType.fromDartType('DateTime').value, 'timestamptz');
    });

    test('nullable types strip ?', () {
      expect(ColumnType.fromDartType('int?').value, 'integer');
      expect(ColumnType.fromDartType('String?').value, 'text');
    });

    test('unknown type → text', () {
      expect(ColumnType.fromDartType('CustomClass').value, 'text');
    });

    test('serial flag overrides', () {
      expect(ColumnType.fromDartType('int', serial: true).value, 'serial');
    });
  });

  group('fromUdtName', () {
    test('int4 → integer', () {
      expect(ColumnType.fromUdtName('int4').value, 'integer');
    });

    test('int2 → smallint', () {
      expect(ColumnType.fromUdtName('int2').value, 'smallint');
    });

    test('int8 → bigint', () {
      expect(ColumnType.fromUdtName('int8').value, 'bigint');
    });

    test('float4 → real', () {
      expect(ColumnType.fromUdtName('float4').value, 'real');
    });

    test('float8 → double precision', () {
      expect(ColumnType.fromUdtName('float8').value, 'double precision');
    });

    test('bool → boolean', () {
      expect(ColumnType.fromUdtName('bool').value, 'boolean');
    });

    test('varchar with length', () {
      expect(
        ColumnType.fromUdtName('varchar', charMaxLength: '100').value,
        'varchar(100)',
      );
    });

    test('varchar without length', () {
      expect(ColumnType.fromUdtName('varchar').value, 'varchar');
    });

    test('pass-through types', () {
      expect(ColumnType.fromUdtName('text').value, 'text');
      expect(ColumnType.fromUdtName('timestamptz').value, 'timestamptz');
      expect(ColumnType.fromUdtName('jsonb').value, 'jsonb');
      expect(ColumnType.fromUdtName('uuid').value, 'uuid');
      expect(ColumnType.fromUdtName('bytea').value, 'bytea');
    });

    test('unknown passes through', () {
      expect(ColumnType.fromUdtName('custom_type').value, 'custom_type');
    });
  });

  group('isEquivalentTo', () {
    test('same type is equivalent', () {
      expect(
        const ColumnType('integer').isEquivalentTo(const ColumnType('integer')),
        isTrue,
      );
    });

    test('serial ≡ integer', () {
      expect(
        const ColumnType('serial').isEquivalentTo(const ColumnType('integer')),
        isTrue,
      );
      expect(
        const ColumnType('integer').isEquivalentTo(const ColumnType('serial')),
        isTrue,
      );
    });

    test('bigserial ≡ bigint', () {
      expect(
        const ColumnType('bigserial')
            .isEquivalentTo(const ColumnType('bigint')),
        isTrue,
      );
    });

    test('smallserial ≡ smallint', () {
      expect(
        const ColumnType('smallserial')
            .isEquivalentTo(const ColumnType('smallint')),
        isTrue,
      );
    });

    test('different types are not equivalent', () {
      expect(
        const ColumnType('integer').isEquivalentTo(const ColumnType('text')),
        isFalse,
      );
    });
  });

  group('equality', () {
    test('same value are equal', () {
      expect(const ColumnType('integer'), equals(const ColumnType('integer')));
    });

    test('different values are not equal', () {
      expect(
        const ColumnType('integer'),
        isNot(equals(const ColumnType('text'))),
      );
    });
  });
}
