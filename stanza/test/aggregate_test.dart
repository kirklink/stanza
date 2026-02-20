import 'package:stanza/stanza.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  late $UserTable users;
  late $PostTable posts;
  late ParameterCollector params;

  setUp(() {
    users = $UserTable();
    posts = $PostTable();
    params = ParameterCollector();
  });

  group('AggregateExpression', () {
    test('COUNT renders correctly', () {
      final agg = users.id.count();
      expect(agg.toSql(), 'COUNT(users.id)');
    });

    test('SUM renders correctly', () {
      final agg = users.id.sum();
      expect(agg.toSql(), 'SUM(users.id)');
    });

    test('AVG renders correctly', () {
      final agg = users.id.avg();
      expect(agg.toSql(), 'AVG(users.id)');
    });

    test('MIN renders correctly', () {
      final agg = users.id.min();
      expect(agg.toSql(), 'MIN(users.id)');
    });

    test('MAX renders correctly', () {
      final agg = users.createdAt.max();
      expect(agg.toSql(), 'MAX(users.created_at)');
    });

    test('as() adds alias', () {
      final agg = users.id.count().as('user_count');
      expect(agg.toSelectSql(), 'COUNT(users.id) AS user_count');
    });

    test('toSelectSql without alias is same as toSql', () {
      final agg = users.id.count();
      expect(agg.toSelectSql(), agg.toSql());
    });

    test('CountAll renders COUNT(*)', () {
      const agg = CountAll();
      expect(agg.toSql(), 'COUNT(*)');
    });

    test('CountAll with alias', () {
      const agg = CountAll(alias: 'total');
      expect(agg.toSelectSql(), 'COUNT(*) AS total');
    });
  });

  group('AggregateComparison (HAVING expressions)', () {
    test('greaterThan', () {
      final expr = users.id.count().greaterThan(5);
      expect(expr.toSql(params), 'COUNT(users.id) > @p0');
    });

    test('greaterThanOrEqual', () {
      final expr = users.id.count().greaterThanOrEqual(10);
      expect(expr.toSql(params), 'COUNT(users.id) >= @p0');
    });

    test('lessThan', () {
      final expr = users.id.count().lessThan(3);
      expect(expr.toSql(params), 'COUNT(users.id) < @p0');
    });

    test('lessThanOrEqual', () {
      final expr = users.id.count().lessThanOrEqual(100);
      expect(expr.toSql(params), 'COUNT(users.id) <= @p0');
    });

    test('equals', () {
      final expr = users.id.count().equals(1);
      expect(expr.toSql(params), 'COUNT(users.id) = @p0');
    });

    test('notEquals', () {
      final expr = users.id.count().notEquals(0);
      expect(expr.toSql(params), 'COUNT(users.id) != @p0');
    });

    test('between', () {
      final expr = users.id.count().between(1, 10);
      expect(expr.toSql(params), 'COUNT(users.id) BETWEEN @p0 AND @p1');
    });
  });

  group('GROUP BY', () {
    test('single column', () {
      final q = SelectQuery(posts)
          .selectOnly((t) => [t.authorId])
          .selectExpression(const CountAll(alias: 'count'))
          .groupBy((t) => [t.authorId]);
      expect(
        q.toSql(params),
        'SELECT posts.author_id, COUNT(*) AS count '
        'FROM posts '
        'GROUP BY posts.author_id',
      );
    });

    test('multiple columns', () {
      final q = SelectQuery(posts)
          .selectOnly((t) => [t.authorId, t.title])
          .selectExpression(const CountAll(alias: 'count'))
          .groupBy((t) => [t.authorId, t.title]);
      expect(
        q.toSql(params),
        'SELECT posts.author_id, posts.title, COUNT(*) AS count '
        'FROM posts '
        'GROUP BY posts.author_id, posts.title',
      );
    });
  });

  group('HAVING', () {
    test('with aggregate comparison', () {
      final q = SelectQuery(posts)
          .selectOnly((t) => [t.authorId])
          .selectExpression(posts.id.count().as('post_count'))
          .groupBy((t) => [t.authorId])
          .having((t) => t.id.count().greaterThan(5));
      expect(
        q.toSql(params),
        'SELECT posts.author_id, COUNT(posts.id) AS post_count '
        'FROM posts '
        'GROUP BY posts.author_id '
        'HAVING COUNT(posts.id) > @p0',
      );
    });

    test('with compound condition using &', () {
      final q = SelectQuery(posts)
          .selectOnly((t) => [t.authorId])
          .groupBy((t) => [t.authorId])
          .having(
            (t) =>
                t.id.count().greaterThan(2) & t.id.count().lessThan(100),
          );
      expect(
        q.toSql(params),
        'SELECT posts.author_id '
        'FROM posts '
        'GROUP BY posts.author_id '
        'HAVING (COUNT(posts.id) > @p0 AND COUNT(posts.id) < @p1)',
      );
    });

    test('with compound condition using |', () {
      final q = SelectQuery(posts)
          .selectOnly((t) => [t.authorId])
          .groupBy((t) => [t.authorId])
          .having(
            (t) =>
                t.id.count().equals(1) | t.id.count().greaterThan(10),
          );
      expect(
        q.toSql(params),
        'SELECT posts.author_id '
        'FROM posts '
        'GROUP BY posts.author_id '
        'HAVING (COUNT(posts.id) = @p0 OR COUNT(posts.id) > @p1)',
      );
    });

    test('multiple having calls are ANDed', () {
      final q = SelectQuery(posts)
          .selectOnly((t) => [t.authorId])
          .groupBy((t) => [t.authorId])
          .having((t) => t.id.count().greaterThan(1))
          .having((t) => t.id.count().lessThan(50));
      expect(
        q.toSql(params),
        'SELECT posts.author_id '
        'FROM posts '
        'GROUP BY posts.author_id '
        'HAVING (COUNT(posts.id) > @p0 AND COUNT(posts.id) < @p1)',
      );
    });
  });

  group('selectExpression', () {
    test('adds aggregate to SELECT with table.*', () {
      final q = SelectQuery(posts)
          .selectExpression(posts.id.count().as('total'));
      expect(
        q.toSql(params),
        'SELECT posts.*, COUNT(posts.id) AS total FROM posts',
      );
    });

    test('adds multiple aggregates', () {
      final q = SelectQuery(users)
          .selectExpression(users.id.count().as('count'))
          .selectExpression(users.id.max().as('max_id'));
      expect(
        q.toSql(params),
        'SELECT users.*, COUNT(users.id) AS count, MAX(users.id) AS max_id '
        'FROM users',
      );
    });
  });

  group('full composition', () {
    test('WHERE + GROUP BY + HAVING + ORDER BY + LIMIT', () {
      final q = SelectQuery(posts)
          .selectOnly((t) => [t.authorId])
          .selectExpression(posts.id.count().as('post_count'))
          .where((t) => t.createdAt.after(DateTime(2025)))
          .groupBy((t) => [t.authorId])
          .having((t) => t.id.count().greaterThan(3))
          .orderBy((t) => t.authorId.asc())
          .limit(10);
      expect(
        q.toSql(params),
        'SELECT posts.author_id, COUNT(posts.id) AS post_count '
        'FROM posts '
        'WHERE posts.created_at > @p0 '
        'GROUP BY posts.author_id '
        'HAVING COUNT(posts.id) > @p1 '
        'ORDER BY posts.author_id ASC '
        'LIMIT 10',
      );
    });

    test('SUM and AVG on IntColumn', () {
      final q = SelectQuery(posts)
          .selectOnly((t) => [t.authorId])
          .selectExpression(posts.authorId.sum().as('total'))
          .selectExpression(posts.authorId.avg().as('average'))
          .groupBy((t) => [t.authorId]);
      expect(
        q.toSql(params),
        'SELECT posts.author_id, SUM(posts.author_id) AS total, '
        'AVG(posts.author_id) AS average '
        'FROM posts '
        'GROUP BY posts.author_id',
      );
    });

    test('COUNT with JOIN', () {
      final q = SelectQuery(posts)
          .selectOnly((t) => [t.authorId])
          .selectExpression(posts.id.count().as('count'))
          .innerJoin(users, (p, u) => p.authorId.equalsColumn(u.id))
          .groupBy((t) => [t.authorId]);
      expect(
        q.toSql(params),
        'SELECT posts.author_id, COUNT(posts.id) AS count '
        'FROM posts '
        'INNER JOIN users ON posts.author_id = users.id '
        'GROUP BY posts.author_id',
      );
    });
  });

  group('compile-time type safety', () {
    test('sum() available on IntColumn', () {
      // This compiles — IntColumn has sum()
      final agg = users.id.sum();
      expect(agg.function, 'SUM');
    });

    test('avg() available on IntColumn', () {
      final agg = users.id.avg();
      expect(agg.function, 'AVG');
    });

    test('count/min/max available on all column types', () {
      // StringColumn
      expect(users.email.count().function, 'COUNT');
      expect(users.email.min().function, 'MIN');
      expect(users.email.max().function, 'MAX');

      // DateTimeColumn
      expect(users.createdAt.count().function, 'COUNT');
      expect(users.createdAt.min().function, 'MIN');
      expect(users.createdAt.max().function, 'MAX');

      // BoolColumn — no bool columns in helpers, but Column<T> base has them
    });
  });
}
