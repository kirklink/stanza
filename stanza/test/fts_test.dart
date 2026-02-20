import 'package:stanza/stanza.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  late $PostTable posts;
  late $UserTable users;
  late ParameterCollector params;

  setUp(() {
    posts = $PostTable();
    users = $UserTable();
    params = ParameterCollector();
  });

  group('fullTextMatches', () {
    test('default config (plain, english)', () {
      final expr = posts.body.fullTextMatches('database optimization');
      expect(
        expr.toSql(params),
        "to_tsvector('english', posts.body) @@ "
        "plainto_tsquery('english', @p0)",
      );
    });

    test('websearch query type', () {
      final expr = posts.body.fullTextMatches(
        '"exact phrase" -exclude',
        queryType: FtsQueryType.websearch,
      );
      expect(
        expr.toSql(params),
        "to_tsvector('english', posts.body) @@ "
        "websearch_to_tsquery('english', @p0)",
      );
    });

    test('phrase query type', () {
      final expr = posts.body.fullTextMatches(
        'quick brown fox',
        queryType: FtsQueryType.phrase,
      );
      expect(
        expr.toSql(params),
        "to_tsvector('english', posts.body) @@ "
        "phraseto_tsquery('english', @p0)",
      );
    });

    test('custom config (spanish)', () {
      final expr = posts.body.fullTextMatches(
        'base de datos',
        config: FtsConfig.spanish,
      );
      expect(
        expr.toSql(params),
        "to_tsvector('spanish', posts.body) @@ "
        "plainto_tsquery('spanish', @p0)",
      );
    });
  });

  group('trigram similarity', () {
    test('isSimilarTo renders % operator', () {
      final expr = users.name.isSimilarTo('jonh');
      expect(expr.toSql(params), 'users.name % @p0');
    });

    test('isWordSimilarTo renders %> operator', () {
      final expr = users.name.isWordSimilarTo('jonh');
      expect(expr.toSql(params), '@p0 %> users.name');
    });
  });

  group('FTS + trigram composed with & / |', () {
    test('FTS AND trigram', () {
      final expr = posts.body.fullTextMatches('search term') &
          posts.title.isSimilarTo('sarch');
      expect(
        expr.toSql(params),
        "(to_tsvector('english', posts.body) @@ "
        "plainto_tsquery('english', @p0) "
        "AND posts.title % @p1)",
      );
    });

    test('FTS OR trigram', () {
      final expr = posts.body.fullTextMatches('search term') |
          posts.title.isSimilarTo('sarch');
      expect(
        expr.toSql(params),
        "(to_tsvector('english', posts.body) @@ "
        "plainto_tsquery('english', @p0) "
        "OR posts.title % @p1)",
      );
    });
  });

  group('selectRank', () {
    test('adds ts_rank to SELECT and ORDER BY', () {
      final q = SelectQuery(posts)
          .where((t) => t.body.fullTextMatches('optimization'))
          .selectRank((t) => t.body, 'optimization');
      expect(
        q.toSql(params),
        "SELECT posts.*, ts_rank(to_tsvector('english', posts.body), "
        "plainto_tsquery('english', @p0)) AS rank "
        "FROM posts "
        "WHERE to_tsvector('english', posts.body) @@ "
        "plainto_tsquery('english', @p1) "
        "ORDER BY ts_rank(to_tsvector('english', posts.body), "
        "plainto_tsquery('english', @p2)) DESC",
      );
    });

    test('with orderByRank: false', () {
      final q = SelectQuery(posts)
          .selectRank((t) => t.body, 'test', orderByRank: false);
      expect(
        q.toSql(params),
        "SELECT posts.*, ts_rank(to_tsvector('english', posts.body), "
        "plainto_tsquery('english', @p0)) AS rank "
        "FROM posts",
      );
    });
  });

  group('selectHeadline', () {
    test('adds ts_headline to SELECT', () {
      final q = SelectQuery(posts)
          .selectHeadline((t) => t.body, 'optimization');
      expect(
        q.toSql(params),
        "SELECT posts.*, ts_headline('english', posts.body, "
        "plainto_tsquery('english', @p0)) AS headline "
        "FROM posts",
      );
    });

    test('with custom options', () {
      final q = SelectQuery(posts).selectHeadline(
        (t) => t.body,
        'optimization',
        options: 'StartSel=<b>, StopSel=</b>',
      );
      expect(
        q.toSql(params),
        "SELECT posts.*, ts_headline('english', posts.body, "
        "plainto_tsquery('english', @p0), "
        "'StartSel=<b>, StopSel=</b>') AS headline "
        "FROM posts",
      );
    });
  });

  group('selectSimilarity', () {
    test('adds similarity() to SELECT and ORDER BY', () {
      final q = SelectQuery(users)
          .where((t) => t.name.isSimilarTo('jonh'))
          .selectSimilarity((t) => t.name, 'jonh');
      expect(
        q.toSql(params),
        'SELECT users.*, similarity(users.name, @p0) AS similarity_score '
        'FROM users '
        'WHERE users.name % @p1 '
        'ORDER BY similarity(users.name, @p2) DESC',
      );
    });

    test('with orderBySimilarity: false', () {
      final q = SelectQuery(users)
          .selectSimilarity((t) => t.name, 'jonh', orderBySimilarity: false);
      expect(
        q.toSql(params),
        'SELECT users.*, similarity(users.name, @p0) AS similarity_score '
        'FROM users',
      );
    });
  });

  group('orderByDistance', () {
    test('renders <-> operator in ORDER BY', () {
      final q = SelectQuery(users)
          .where((t) => t.name.isSimilarTo('jonh'))
          .orderByDistance((t) => t.name, 'jonh');
      expect(
        q.toSql(params),
        'SELECT users.* FROM users '
        'WHERE users.name % @p0 '
        'ORDER BY users.name <-> @p1',
      );
    });
  });

  group('combined FTS', () {
    test('FTS WHERE + rank SELECT + headline SELECT', () {
      final q = SelectQuery(posts)
          .where((t) => t.body.fullTextMatches('optimization'))
          .selectRank((t) => t.body, 'optimization')
          .selectHeadline((t) => t.body, 'optimization');
      final sql = q.toSql(params);
      expect(sql, contains("ts_rank("));
      expect(sql, contains("ts_headline("));
      expect(sql, contains("@@ plainto_tsquery"));
      expect(sql, contains("ORDER BY"));
    });

    test('all values are parameterized', () {
      final q = SelectQuery(posts)
          .where((t) => t.body.fullTextMatches('test query'))
          .selectRank((t) => t.body, 'test query');
      q.toSql(params);
      // All query values should be registered in the collector
      expect(params.values.values, everyElement(equals('test query')));
    });
  });
}
