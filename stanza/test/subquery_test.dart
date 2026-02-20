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

  group('isInQuery', () {
    test('renders correct SQL with shared parameters', () {
      final subquery = SelectQuery(users)
          .selectOnly((t) => [t.id])
          .where((t) => t.createdAt.after(DateTime(2025)));

      final q = SelectQuery(posts)
          .where((t) => t.authorId.isInQuery(subquery));

      expect(
        q.toSql(params),
        'SELECT posts.* FROM posts '
        'WHERE posts.author_id IN '
        '(SELECT users.id FROM users WHERE users.created_at > @p0)',
      );
    });

    test('subquery parameters merge with outer query', () {
      final subquery = SelectQuery(users)
          .selectOnly((t) => [t.id])
          .where((t) => t.email.like('%@example.com'));

      final q = SelectQuery(posts)
          .where(
            (t) =>
                t.title.contains('Dart') & t.authorId.isInQuery(subquery),
          );

      final sql = q.toSql(params);
      // Outer WHERE uses @p0, subquery uses @p1
      expect(sql, contains('@p0'));
      expect(sql, contains('@p1'));
      expect(
        sql,
        'SELECT posts.* FROM posts '
        'WHERE (posts.title LIKE @p0 AND posts.author_id IN '
        '(SELECT users.id FROM users WHERE users.email LIKE @p1))',
      );
    });
  });

  group('notInQuery', () {
    test('renders correct SQL', () {
      final subquery = SelectQuery(users)
          .selectOnly((t) => [t.id])
          .where((t) => t.name.equals('banned'));

      final q = SelectQuery(posts)
          .where((t) => t.authorId.notInQuery(subquery));

      expect(
        q.toSql(params),
        'SELECT posts.* FROM posts '
        'WHERE posts.author_id NOT IN '
        '(SELECT users.id FROM users WHERE users.name = @p0)',
      );
    });
  });

  group('nested subqueries', () {
    test('subquery with ORDER BY and LIMIT', () {
      final subquery = SelectQuery(users)
          .selectOnly((t) => [t.id])
          .orderBy((t) => t.createdAt.desc())
          .limit(10);

      final q = SelectQuery(posts)
          .where((t) => t.authorId.isInQuery(subquery));

      expect(
        q.toSql(params),
        'SELECT posts.* FROM posts '
        'WHERE posts.author_id IN '
        '(SELECT users.id FROM users ORDER BY users.created_at DESC LIMIT 10)',
      );
    });
  });

  group('subquery combined with other expressions', () {
    test('isInQuery combined with direct where using &', () {
      final subquery = SelectQuery(users)
          .selectOnly((t) => [t.id])
          .where((t) => t.email.like('%@admin.com'));

      final q = SelectQuery(posts)
          .where((t) => t.createdAt.after(DateTime(2025)))
          .where((t) => t.authorId.isInQuery(subquery));

      final sql = q.toSql(params);
      expect(sql, contains('posts.created_at > @p0'));
      expect(sql, contains('IN (SELECT users.id'));
    });
  });
}
