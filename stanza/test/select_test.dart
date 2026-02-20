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

  group('basic SELECT', () {
    test('select all from table', () {
      final q = SelectQuery(users);
      expect(q.toSql(params), 'SELECT users.* FROM users');
      expect(params.values, isEmpty);
    });

    test('select distinct', () {
      final q = SelectQuery(users).distinct();
      expect(q.toSql(params), 'SELECT DISTINCT users.* FROM users');
    });

    test('select specific columns', () {
      final q = SelectQuery(users).selectOnly((t) => [t.email, t.name]);
      expect(
        q.toSql(params),
        'SELECT users.email, users.name FROM users',
      );
    });
  });

  group('WHERE', () {
    test('single where', () {
      final q = SelectQuery(users)
          .where((t) => t.email.equals('foo@bar.com'));
      expect(
        q.toSql(params),
        'SELECT users.* FROM users WHERE users.email = @p0',
      );
      expect(params.values, {'p0': 'foo@bar.com'});
    });

    test('multiple where calls are ANDed', () {
      final q = SelectQuery(users)
          .where((t) => t.email.like('%@example.com'))
          .where((t) => t.name.equals('Kirk'));
      expect(
        q.toSql(params),
        'SELECT users.* FROM users WHERE '
        '(users.email LIKE @p0 AND users.name = @p1)',
      );
    });

    test('where with & (AND)', () {
      final q = SelectQuery(users).where(
        (t) => t.email.like('%@example.com') & t.name.equals('Kirk'),
      );
      expect(
        q.toSql(params),
        'SELECT users.* FROM users WHERE '
        '(users.email LIKE @p0 AND users.name = @p1)',
      );
    });

    test('where with | (OR)', () {
      final q = SelectQuery(users).where(
        (t) => t.name.equals('Kirk') | t.name.equals('Spock'),
      );
      expect(
        q.toSql(params),
        'SELECT users.* FROM users WHERE '
        '(users.name = @p0 OR users.name = @p1)',
      );
    });

    test('where with isNull', () {
      final q = SelectQuery(users).where((t) => t.createdAt.isNull());
      expect(
        q.toSql(params),
        'SELECT users.* FROM users WHERE users.created_at IS NULL',
      );
    });

    test('where with isIn', () {
      final q = SelectQuery(users).where(
        (t) => t.id.isIn([1, 2, 3]),
      );
      expect(
        q.toSql(params),
        'SELECT users.* FROM users WHERE users.id IN (@p0, @p1, @p2)',
      );
    });

    test('where with between', () {
      final q = SelectQuery(users).where(
        (t) => t.id.between(10, 20),
      );
      expect(
        q.toSql(params),
        'SELECT users.* FROM users WHERE users.id BETWEEN @p0 AND @p1',
      );
    });

    test('complex compound where', () {
      final q = SelectQuery(users).where(
        (t) =>
            (t.email.like('%@example.com') & t.name.startsWith('K')) |
            t.id.lessThan(10),
      );
      final sql = q.toSql(params);
      expect(
        sql,
        'SELECT users.* FROM users WHERE '
        '((users.email LIKE @p0 AND users.name LIKE @p1) OR users.id < @p2)',
      );
      expect(params.values, {'p0': '%@example.com', 'p1': 'K%', 'p2': 10});
    });
  });

  group('ORDER BY', () {
    test('single order', () {
      final q = SelectQuery(users).orderBy((t) => t.name.asc());
      expect(
        q.toSql(params),
        'SELECT users.* FROM users ORDER BY users.name ASC',
      );
    });

    test('descending order', () {
      final q = SelectQuery(users).orderBy((t) => t.createdAt.desc());
      expect(
        q.toSql(params),
        'SELECT users.* FROM users ORDER BY users.created_at DESC',
      );
    });

    test('multiple order by', () {
      final q = SelectQuery(users)
          .orderBy((t) => t.name.asc())
          .orderBy((t) => t.createdAt.desc());
      expect(
        q.toSql(params),
        'SELECT users.* FROM users ORDER BY users.name ASC, users.created_at DESC',
      );
    });
  });

  group('LIMIT / OFFSET', () {
    test('limit', () {
      final q = SelectQuery(users).limit(10);
      expect(q.toSql(params), 'SELECT users.* FROM users LIMIT 10');
    });

    test('offset', () {
      final q = SelectQuery(users).offset(20);
      expect(q.toSql(params), 'SELECT users.* FROM users OFFSET 20');
    });

    test('limit and offset', () {
      final q = SelectQuery(users).limit(10).offset(20);
      expect(
        q.toSql(params),
        'SELECT users.* FROM users LIMIT 10 OFFSET 20',
      );
    });
  });

  group('JOINs', () {
    test('inner join', () {
      final q = SelectQuery(posts).innerJoin(
        users,
        (p, u) => p.authorId.equalsColumn(u.id),
      );
      final sql = q.toSql(params);
      expect(
        sql,
        'SELECT posts.* FROM posts '
        'INNER JOIN users ON posts.author_id = users.id',
      );
      expect(params.values, isEmpty);
    });

    test('left join', () {
      final q = SelectQuery(posts).leftJoin(
        users,
        (p, u) => p.authorId.equalsColumn(u.id),
      );
      expect(
        q.toSql(params),
        'SELECT posts.* FROM posts '
        'LEFT JOIN users ON posts.author_id = users.id',
      );
    });

    test('right join', () {
      final q = SelectQuery(posts).rightJoin(
        users,
        (p, u) => p.authorId.equalsColumn(u.id),
      );
      expect(
        q.toSql(params),
        'SELECT posts.* FROM posts '
        'RIGHT JOIN users ON posts.author_id = users.id',
      );
    });
  });

  group('full query composition', () {
    test('select with where, order, limit, offset', () {
      final q = SelectQuery(users)
          .where((t) => t.email.like('%@example.com'))
          .orderBy((t) => t.createdAt.desc())
          .limit(20)
          .offset(40);
      expect(
        q.toSql(params),
        'SELECT users.* FROM users '
        'WHERE users.email LIKE @p0 '
        'ORDER BY users.created_at DESC '
        'LIMIT 20 OFFSET 40',
      );
    });

    test('build() returns sql and parameters', () {
      final q = SelectQuery(users)
          .where((t) => t.name.equals('Kirk'))
          .limit(1);
      final result = q.build();
      expect(result.sql, contains('WHERE users.name = @p0'));
      expect(result.parameters, {'p0': 'Kirk'});
    });
  });
}
