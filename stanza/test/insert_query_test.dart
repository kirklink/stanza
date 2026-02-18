import 'package:test/test.dart';
import 'package:stanza/stanza.dart';
import 'test_helpers.dart';

void main() {
  late AnimalTable t;

  setUp(() {
    t = AnimalTable();
  });

  group('InsertQuery', () {
    test('insert single field', () {
      final q = InsertQuery(t)..insert(t.name, 'Tiger');
      expect(q.statement(), contains('INSERT INTO mammal'));
      expect(q.statement(), contains('(name) VALUES'));
      expect(q.substitutionValues.values.first, 'Tiger');
    });

    test('insert multiple fields', () {
      final q = InsertQuery(t)
        ..insert(t.name, 'Tiger')
        ..insert(t.legs, 4)
        ..insert(t.color, 'orange');
      final stmt = q.statement();
      expect(stmt, contains('name'));
      expect(stmt, contains('number_of_legs'));
      expect(stmt, contains('color'));
    });

    test('insert entity', () {
      final animal = Animal()
        ..name = 'Lion'
        ..legs = 4
        ..color = 'golden';
      final q = InsertQuery(t)..insertEntity<Animal>(animal);
      final stmt = q.statement();
      expect(stmt, contains('INSERT INTO mammal'));
      expect(stmt, contains('name'));
      expect(stmt, contains('number_of_legs'));
      expect(stmt, contains('color'));
      // toDb excludes id (readOnly), so 3 substitution values
      expect(q.substitutionValues.length, 3);
      expect(q.substitutionValues.values, contains('Lion'));
      expect(q.substitutionValues.values, contains(4));
      expect(q.substitutionValues.values, contains('golden'));
    });

    test('insert entity type mismatch throws', () {
      expect(
        () => InsertQuery(t).insertEntity<String>('not an animal'),
        throwsA(isA<StanzaException>()),
      );
    });

    test('substitution values are parameterized', () {
      final q = InsertQuery(t)..insert(t.name, "Robert'; DROP TABLE mammal;--");
      // The value should be in substitutionValues, not interpolated in SQL
      expect(q.statement(), isNot(contains('DROP TABLE')));
      expect(q.substitutionValues.values.first,
          "Robert'; DROP TABLE mammal;--");
    });

    test('fork preserves insert state', () {
      final q = InsertQuery(t)
        ..insert(t.name, 'Tiger')
        ..insert(t.legs, 4);
      final forked = q.fork();
      expect(forked.statement(), q.statement());
      expect(forked.substitutionValues, q.substitutionValues);
    });
  });
}
