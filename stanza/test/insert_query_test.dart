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

  group('InsertQuery batch', () {
    test('insertEntities with multiple entities', () {
      final animals = [
        Animal()..name = 'Tiger'..legs = 4..color = 'orange',
        Animal()..name = 'Eagle'..legs = 2..color = 'brown',
        Animal()..name = 'Snake'..legs = 0..color = 'green',
      ];
      final q = InsertQuery(t)..insertEntities<Animal>(animals);
      final stmt = q.statement();
      expect(stmt, startsWith('INSERT INTO mammal'));
      // Should have 3 value tuples separated by ), (
      expect('), ('.allMatches(stmt).length, 2);
      // 3 entities x 3 fields each = 9 substitution values
      expect(q.substitutionValues.length, 9);
      expect(q.substitutionValues.values, contains('Tiger'));
      expect(q.substitutionValues.values, contains('Eagle'));
      expect(q.substitutionValues.values, contains('Snake'));
    });

    test('insertEntities with single entity', () {
      final animals = [
        Animal()..name = 'Tiger'..legs = 4..color = 'orange',
      ];
      final q = InsertQuery(t)..insertEntities<Animal>(animals);
      final stmt = q.statement();
      expect(stmt, contains('INSERT INTO mammal'));
      expect(stmt, contains('VALUES ('));
      expect(q.substitutionValues.length, 3);
    });

    test('insertEntities with empty list throws', () {
      expect(
        () => InsertQuery(t).insertEntities<Animal>([]),
        throwsA(isA<StanzaException>()),
      );
    });

    test('insertEntities type mismatch throws', () {
      expect(
        () => InsertQuery(t).insertEntities<String>(['not an animal']),
        throwsA(isA<StanzaException>()),
      );
    });

    test('insertEntities with RETURNING', () {
      final animals = [
        Animal()..name = 'Tiger'..legs = 4..color = 'orange',
        Animal()..name = 'Eagle'..legs = 2..color = 'brown',
      ];
      final q = InsertQuery(t)
        ..insertEntities<Animal>(animals)
        ..returningStar();
      final stmt = q.statement();
      expect(stmt, contains('VALUES'));
      expect(stmt, endsWith('RETURNING *'));
    });

    test('fork preserves batch state', () {
      final animals = [
        Animal()..name = 'Tiger'..legs = 4..color = 'orange',
        Animal()..name = 'Eagle'..legs = 2..color = 'brown',
      ];
      final q = InsertQuery(t)..insertEntities<Animal>(animals);
      final forked = q.fork();
      expect(forked.statement(), q.statement());
      expect(forked.substitutionValues, q.substitutionValues);
    });

    test('fork is independent for batch', () {
      final q = InsertQuery(t)
        ..insertEntities<Animal>([
          Animal()..name = 'Tiger'..legs = 4..color = 'orange',
        ]);
      final original = q.statement();
      final forked = q.fork();
      forked.returningStar();
      expect(forked.statement(), contains('RETURNING *'));
      expect(original, isNot(contains('RETURNING')));
    });
  });
}
