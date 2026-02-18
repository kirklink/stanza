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

  group('DISTINCT', () {
    test('distinct emits SELECT DISTINCT', () {
      final q = SelectQuery(t)
        ..distinct()
        ..selectFields([t.color]);
      expect(q.statement(), startsWith('SELECT DISTINCT mammal.color'));
    });

    test('distinct with selectStar', () {
      final q = SelectQuery(t)
        ..distinct()
        ..selectStar();
      expect(q.statement(), startsWith('SELECT DISTINCT mammal.*'));
    });

    test('distinct with where', () {
      final q = SelectQuery(t)
        ..distinct()
        ..selectFields([t.color])
        ..where(t.legs).isGreaterThan(2);
      final stmt = q.statement();
      expect(stmt, startsWith('SELECT DISTINCT'));
      expect(stmt, contains('WHERE'));
    });

    test('without distinct emits plain SELECT', () {
      final q = SelectQuery(t)..selectStar();
      expect(q.statement(), startsWith('SELECT mammal.*'));
      expect(q.statement(), isNot(contains('DISTINCT')));
    });

    test('fork preserves distinct', () {
      final q = SelectQuery(t)
        ..distinct()
        ..selectFields([t.color]);
      final forked = q.fork();
      expect(forked.statement(), contains('SELECT DISTINCT'));
    });

    test('fork is independent for distinct', () {
      final q = SelectQuery(t)..selectStar();
      final forked = q.fork();
      forked.distinct();
      expect(forked.statement(), contains('DISTINCT'));
      expect(q.statement(), isNot(contains('DISTINCT')));
    });
  });

  group('HAVING', () {
    test('having with count aggregate', () {
      final q = SelectQuery(t)
        ..selectFields([t.color, t.id..count()..rename('count')])
        ..groupBy([t.color])
        ..having(t.id..count()).isGreaterThan(2);
      final stmt = q.statement();
      expect(stmt, contains('GROUP BY'));
      expect(stmt, contains('HAVING COUNT(mammal.id) >'));
    });

    test('having with sum aggregate', () {
      final q = SelectQuery(t)
        ..selectFields([t.color, t.legs..sum()..rename('total_legs')])
        ..groupBy([t.color])
        ..having(t.legs..sum()).isGreaterThan(10);
      final stmt = q.statement();
      expect(stmt, contains('HAVING SUM(mammal.number_of_legs) >'));
    });

    test('having with andHaving', () {
      final q = SelectQuery(t)
        ..selectFields([t.color, t.id..count()..rename('count')])
        ..groupBy([t.color])
        ..having(t.id..count()).isGreaterThan(1)
        ..andHaving(t.id..count()).isLessThan(10);
      final stmt = q.statement();
      expect(stmt, contains('HAVING COUNT(mammal.id) >'));
      expect(stmt, contains('AND COUNT(mammal.id) <'));
    });

    test('having with orHaving', () {
      final q = SelectQuery(t)
        ..selectFields([t.color, t.id..count()..rename('count')])
        ..groupBy([t.color])
        ..having(t.id..count()).isEqualTo(1)
        ..orHaving(t.id..count()).isGreaterThan(5);
      final stmt = q.statement();
      expect(stmt, contains('HAVING COUNT(mammal.id) ='));
      expect(stmt, contains('OR COUNT(mammal.id) >'));
    });

    test('having appears after GROUP BY', () {
      final q = SelectQuery(t)
        ..selectFields([t.color, t.id..count()..rename('count')])
        ..groupBy([t.color])
        ..having(t.id..count()).isGreaterThan(2);
      final stmt = q.statement();
      final groupIdx = stmt.indexOf('GROUP BY');
      final havingIdx = stmt.indexOf('HAVING');
      expect(groupIdx, lessThan(havingIdx));
    });

    test('having appears before ORDER BY', () {
      final q = SelectQuery(t)
        ..selectFields([t.color, t.id..count()..rename('count')])
        ..groupBy([t.color])
        ..having(t.id..count()).isGreaterThan(2)
        ..orderBy(t.color);
      final stmt = q.statement();
      final havingIdx = stmt.indexOf('HAVING');
      final orderIdx = stmt.indexOf('ORDER BY');
      expect(havingIdx, lessThan(orderIdx));
    });

    test('duplicate having throws', () {
      final q = SelectQuery(t)
        ..selectFields([t.color])
        ..groupBy([t.color])
        ..having(t.id..count()).isGreaterThan(1);
      expect(
        () => q.having(t.id..count()).isGreaterThan(5),
        throwsA(isA<StanzaException>()),
      );
    });

    test('andHaving without having throws', () {
      final q = SelectQuery(t)..selectStar();
      expect(
        () => q.andHaving(t.id..count()).isGreaterThan(1),
        throwsA(isA<StanzaException>()),
      );
    });

    test('orHaving without having throws', () {
      final q = SelectQuery(t)..selectStar();
      expect(
        () => q.orHaving(t.id..count()).isGreaterThan(1),
        throwsA(isA<StanzaException>()),
      );
    });

    test('fork preserves having', () {
      final q = SelectQuery(t)
        ..selectFields([t.color, t.id..count()..rename('count')])
        ..groupBy([t.color])
        ..having(t.id..count()).isGreaterThan(2);
      final forked = q.fork();
      expect(forked.statement(), contains('HAVING'));
    });

    test('fork is independent for having', () {
      final q = SelectQuery(t)
        ..selectFields([t.color, t.id..count()..rename('count')])
        ..groupBy([t.color]);
      final forked = q.fork();
      forked.having(t.id..count()).isGreaterThan(2);
      expect(forked.statement(), contains('HAVING'));
      expect(q.statement(), isNot(contains('HAVING')));
    });
  });
}
