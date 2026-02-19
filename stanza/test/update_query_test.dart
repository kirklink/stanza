import 'package:test/test.dart';
import 'package:stanza/stanza.dart';
import 'test_helpers.dart';

void main() {
  late AnimalTable t;

  setUp(() {
    t = AnimalTable();
  });

  group('UpdateQuery', () {
    test('update single column with string', () {
      final q = UpdateQuery(t)
        ..column(t.name).string('Lion')
        ..where(t.id).isEqualTo(1);
      final stmt = q.statement();
      expect(stmt, startsWith('UPDATE mammal'));
      expect(stmt, contains('SET name ='));
      expect(stmt, contains('WHERE mammal.id ='));
    });

    test('update multiple columns', () {
      final q = UpdateQuery(t)
        ..column(t.name).string('Lion')
        ..column(t.color).string('golden')
        ..where(t.id).isEqualTo(1);
      final stmt = q.statement();
      expect(stmt, contains('name ='));
      expect(stmt, contains('color ='));
      // Values should be parameterized
      expect(q.substitutionValues.values, contains('Lion'));
      expect(q.substitutionValues.values, contains('golden'));
    });

    test('update with number', () {
      final q = UpdateQuery(t)
        ..column(t.legs).number(6)
        ..where(t.id).isEqualTo(1);
      expect(q.substitutionValues.values, contains(6));
    });

    test('update with integer', () {
      final q = UpdateQuery(t)
        ..column(t.legs).integer(8)
        ..where(t.id).isEqualTo(1);
      expect(q.substitutionValues.values, contains(8));
    });

    test('update with float', () {
      final q = UpdateQuery(t)
        ..column(t.legs).float(3.14)
        ..where(t.id).isEqualTo(1);
      expect(q.substitutionValues.values, contains(3.14));
    });

    test('update with boolean', () {
      final q = UpdateQuery(t)
        ..column(t.legs).boolean(true)
        ..where(t.id).isEqualTo(1);
      expect(q.substitutionValues.values, contains(true));
    });

    test('update with datetime', () {
      final dt = DateTime(2024, 1, 15);
      final q = UpdateQuery(t)
        ..column(t.legs).datetime(dt)
        ..where(t.id).isEqualTo(1);
      expect(q.substitutionValues.values, contains(dt));
    });

    test('update with any (dynamic)', () {
      final q = UpdateQuery(t)
        ..column(t.name).any('dynamic_value')
        ..where(t.id).isEqualTo(1);
      expect(q.substitutionValues.values, contains('dynamic_value'));
    });

    test('update without where still produces statement', () {
      final q = UpdateQuery(t)..column(t.name).string('Lion');
      final stmt = q.statement();
      expect(stmt, startsWith('UPDATE mammal'));
      expect(stmt, contains('SET name ='));
      // No WHERE clause
      expect(stmt, isNot(contains('WHERE')));
    });

    test('fork preserves update state', () {
      final q = UpdateQuery(t)
        ..column(t.name).string('Lion')
        ..where(t.id).isEqualTo(1);
      final forked = q.fork();
      expect(forked.statement(), q.statement());
      expect(forked.substitutionValues, q.substitutionValues);
    });

    test('fork is independent of original', () {
      final q = UpdateQuery(t)
        ..column(t.name).string('Lion')
        ..where(t.id).isEqualTo(1);
      final forked = q.fork();
      forked.column(t.color).string('golden');
      expect(forked.statement(), contains('color ='));
      expect(q.statement(), isNot(contains('color =')));
    });
  });
}
