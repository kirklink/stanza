import 'package:test/test.dart';
import 'package:stanza/stanza.dart';

void main() {
  group('Field', () {
    test('name returns field name', () {
      final f = Field('mammal', 'color');
      expect(f.name, 'color');
    });

    test('qualifiedName returns table.field', () {
      final f = Field('mammal', 'color');
      expect(f.qualifiedName, 'mammal.color');
    });

    test('sql returns qualified name by default', () {
      final f = Field('mammal', 'color');
      expect(f.sql, 'mammal.color');
    });

    test('rename adds AS alias', () {
      final f = Field('mammal', 'color')..rename('animal_color');
      expect(f.sql, 'mammal.color AS animal_color');
    });

    test('sum wraps in SUM()', () {
      final f = Field('mammal', 'number_of_legs')..sum();
      expect(f.sql, 'SUM(mammal.number_of_legs)');
    });

    test('avg wraps in AVG()', () {
      final f = Field('mammal', 'number_of_legs')..avg();
      expect(f.sql, 'AVG(mammal.number_of_legs)');
    });

    test('count wraps in COUNT()', () {
      final f = Field('mammal', 'id')..count();
      expect(f.sql, 'COUNT(mammal.id)');
    });

    test('max wraps in MAX()', () {
      final f = Field('mammal', 'number_of_legs')..max();
      expect(f.sql, 'MAX(mammal.number_of_legs)');
    });

    test('min wraps in MIN()', () {
      final f = Field('mammal', 'number_of_legs')..min();
      expect(f.sql, 'MIN(mammal.number_of_legs)');
    });

    test('aggregate with custom operation', () {
      final f = Field('mammal', 'number_of_legs')..aggregate('STDDEV');
      expect(f.sql, 'STDDEV(mammal.number_of_legs)');
    });

    test('aggregate with rename', () {
      final f = Field('mammal', 'id')
        ..count()
        ..rename('total');
      expect(f.sql, 'COUNT(mammal.id) AS total');
    });

    test('expressionName without aggregate returns qualifiedName', () {
      final f = Field('mammal', 'color');
      expect(f.expressionName, 'mammal.color');
    });

    test('expressionName with aggregate wraps in operation', () {
      final f = Field('mammal', 'id')..count();
      expect(f.expressionName, 'COUNT(mammal.id)');
    });
  });
}
