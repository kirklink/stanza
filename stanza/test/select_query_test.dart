import 'package:test/test.dart';
import 'package:stanza/stanza.dart';
import 'test_helpers.dart';

void main() {
  late AnimalTable t;

  setUp(() {
    t = AnimalTable();
  });

  group('SelectQuery', () {
    test('select star', () {
      final q = SelectQuery(t)..selectStar();
      expect(q.statement(), 'SELECT mammal.* FROM mammal');
    });

    test('select specific fields', () {
      final q = SelectQuery(t)..selectFields([t.name, t.color]);
      expect(q.statement(), 'SELECT mammal.name, mammal.color FROM mammal');
    });

    test('select with aggregate', () {
      final q = SelectQuery(t)
        ..selectFields([t.id..count()..rename('total')]);
      expect(q.statement(), 'SELECT COUNT(mammal.id) AS total FROM mammal');
    });

    test('select star with where', () {
      final q = SelectQuery(t)
        ..selectStar()
        ..where(t.legs).isGreaterThan(2);
      expect(q.statement(),
          'SELECT mammal.* FROM mammal WHERE mammal.number_of_legs > @mammal_number_of_legs_0');
      expect(q.substitutionValues['mammal_number_of_legs_0'], 2);
    });

    test('select with multiple where (AND)', () {
      final q = SelectQuery(t)
        ..selectStar()
        ..where(t.legs).isGreaterThan(2)
        ..and(t.color).matches('brown');
      final stmt = q.statement();
      expect(stmt, contains('WHERE mammal.number_of_legs >'));
      expect(stmt, contains('AND LOWER(mammal.color) ='));
      expect(q.substitutionValues.values, contains('brown'));
    });

    test('select with OR', () {
      final q = SelectQuery(t)
        ..selectStar()
        ..where(t.color).matches('brown')
        ..or(t.color).matches('white');
      expect(q.statement(), contains('OR LOWER(mammal.color) ='));
    });

    test('select with brackets in where', () {
      final q = SelectQuery(t)
        ..selectStar()
        ..where(t.legs, openBracket: true).isEqualTo(4)
        ..or(t.legs, closeBracket: true).isEqualTo(2);
      final stmt = q.statement();
      expect(stmt, contains('(mammal.number_of_legs ='));
      expect(stmt, contains('mammal.number_of_legs ='));
      // Should have closing bracket
      expect(stmt, contains(')'));
    });

    test('select with GROUP BY', () {
      final q = SelectQuery(t)
        ..selectFields([t.color, t.id..count()..rename('count')])
        ..groupBy([t.color]);
      expect(q.statement(), contains('GROUP BY mammal.color'));
    });

    test('groupBy throws on duplicate', () {
      final q = SelectQuery(t)
        ..selectStar()
        ..groupBy([t.color]);
      expect(() => q.groupBy([t.name]), throwsA(isA<StanzaException>()));
    });

    test('select with ORDER BY ascending', () {
      final q = SelectQuery(t)
        ..selectStar()
        ..orderBy(t.name);
      expect(q.statement(), contains('ORDER BY mammal.name ASC'));
    });

    test('select with ORDER BY descending', () {
      final q = SelectQuery(t)
        ..selectStar()
        ..orderBy(t.name, descending: true);
      expect(q.statement(), contains('ORDER BY mammal.name DESC'));
    });

    test('select with multiple ORDER BY', () {
      final q = SelectQuery(t)
        ..selectStar()
        ..orderBy(t.color)
        ..orderBy(t.name, descending: true);
      expect(q.statement(),
          contains('ORDER BY mammal.color ASC, mammal.name DESC'));
    });

    test('select with LIMIT', () {
      final q = SelectQuery(t)
        ..selectStar()
        ..limit(10);
      expect(q.statement(), contains('LIMIT 10'));
    });

    test('limit throws on duplicate', () {
      final q = SelectQuery(t)
        ..selectStar()
        ..limit(10);
      expect(() => q.limit(5), throwsA(isA<StanzaException>()));
    });

    test('select with OFFSET', () {
      final q = SelectQuery(t)
        ..selectStar()
        ..offset(20);
      expect(q.statement(), contains('OFFSET 20'));
    });

    test('offset throws on duplicate', () {
      final q = SelectQuery(t)
        ..selectStar()
        ..offset(20);
      expect(() => q.offset(10), throwsA(isA<StanzaException>()));
    });

    test('select with LIMIT and OFFSET', () {
      final q = SelectQuery(t)
        ..selectStar()
        ..limit(10)
        ..offset(20);
      final stmt = q.statement();
      expect(stmt, contains('LIMIT 10'));
      expect(stmt, contains('OFFSET 20'));
    });

    test('full query with all clauses', () {
      final q = SelectQuery(t)
        ..selectStar()
        ..where(t.legs).isGreaterThan(0)
        ..orderBy(t.name)
        ..limit(10)
        ..offset(5);
      final stmt = q.statement();
      expect(stmt, startsWith('SELECT mammal.* FROM mammal'));
      expect(stmt, contains('WHERE'));
      expect(stmt, contains('ORDER BY'));
      expect(stmt, contains('LIMIT 10'));
      expect(stmt, contains('OFFSET 5'));
    });

    test('pretty print adds newlines', () {
      final q = SelectQuery(t)
        ..selectStar()
        ..where(t.legs).isEqualTo(4)
        ..limit(10);
      final stmt = q.statement(pretty: true);
      expect(stmt, contains('\n'));
    });

    test('fork preserves query state', () {
      final q = SelectQuery(t)
        ..selectStar()
        ..where(t.color).matches('brown')
        ..limit(10);
      final forked = q.fork();
      expect(forked.statement(), q.statement());
      expect(forked.substitutionValues, q.substitutionValues);
    });

    test('fork is independent of original', () {
      final q = SelectQuery(t)
        ..selectStar()
        ..where(t.color).matches('brown');
      final forked = q.fork();
      forked.limit(5);
      expect(forked.statement(), contains('LIMIT 5'));
      expect(q.statement(), isNot(contains('LIMIT')));
    });
  });
}
