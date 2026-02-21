import 'package:stanza/stanza.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  late $PostTable posts;
  late ParameterCollector params;

  setUp(() {
    posts = $PostTable();
    params = ParameterCollector();
  });

  group('Fts5Match expression', () {
    test('renders MATCH with parameter', () {
      final expr = Fts5Match('posts_fts', 'database optimization');
      expect(expr.toSql(params), 'posts_fts MATCH @p0');
      expect(params.values, {'p0': 'database optimization'});
    });

    test('composes with & (AND)', () {
      final expr =
          Fts5Match('posts_fts', 'search') & Comparison('posts.id', '>', 10);
      expect(
        expr.toSql(params),
        '(posts_fts MATCH @p0 AND posts.id > @p1)',
      );
    });

    test('composes with | (OR)', () {
      final expr =
          Fts5Match('posts_fts', 'first') | Fts5Match('posts_fts', 'second');
      expect(
        expr.toSql(params),
        '(posts_fts MATCH @p0 OR posts_fts MATCH @p1)',
      );
    });
  });

  group('fts5Join', () {
    test('renders JOIN + WHERE MATCH', () {
      final q = SelectQuery(posts)
          .fts5Join('posts_fts', (t) => t.id, 'database optimization');
      expect(
        q.toSql(params),
        'SELECT posts.* FROM posts '
        'JOIN posts_fts ON posts.id = posts_fts.rowid '
        'WHERE posts_fts MATCH @p0',
      );
      expect(params.values, {'p0': 'database optimization'});
    });
  });

  group('selectFts5Rank', () {
    test('adds bm25 to SELECT and ORDER BY', () {
      final q = SelectQuery(posts)
          .fts5Join('posts_fts', (t) => t.id, 'test')
          .selectFts5Rank('posts_fts');
      expect(
        q.toSql(params),
        'SELECT posts.*, bm25(posts_fts) AS rank '
        'FROM posts '
        'JOIN posts_fts ON posts.id = posts_fts.rowid '
        'WHERE posts_fts MATCH @p0 '
        'ORDER BY bm25(posts_fts)',
      );
    });

    test('with weights', () {
      final q = SelectQuery(posts)
          .fts5Join('posts_fts', (t) => t.id, 'test')
          .selectFts5Rank('posts_fts', weights: [10.0, 1.0]);
      expect(
        q.toSql(params),
        'SELECT posts.*, bm25(posts_fts, 10.0, 1.0) AS rank '
        'FROM posts '
        'JOIN posts_fts ON posts.id = posts_fts.rowid '
        'WHERE posts_fts MATCH @p0 '
        'ORDER BY bm25(posts_fts, 10.0, 1.0)',
      );
    });

    test('with orderByRank: false', () {
      final q = SelectQuery(posts)
          .fts5Join('posts_fts', (t) => t.id, 'test')
          .selectFts5Rank('posts_fts', orderByRank: false);
      expect(
        q.toSql(params),
        'SELECT posts.*, bm25(posts_fts) AS rank '
        'FROM posts '
        'JOIN posts_fts ON posts.id = posts_fts.rowid '
        'WHERE posts_fts MATCH @p0',
      );
    });
  });

  group('selectFts5Highlight', () {
    test('default open/close tags', () {
      final q = SelectQuery(posts)
          .fts5Join('posts_fts', (t) => t.id, 'test')
          .selectFts5Highlight('posts_fts', 1);
      // SELECT fragments render before WHERE, so open/close get @p0/@p1
      // and MATCH query gets @p2
      expect(
        q.toSql(params),
        'SELECT posts.*, highlight(posts_fts, 1, @p0, @p1) AS headline '
        'FROM posts '
        'JOIN posts_fts ON posts.id = posts_fts.rowid '
        'WHERE posts_fts MATCH @p2',
      );
      expect(params.values['p0'], '<b>');
      expect(params.values['p1'], '</b>');
      expect(params.values['p2'], 'test');
    });

    test('custom tags and alias', () {
      final q = SelectQuery(posts)
          .fts5Join('posts_fts', (t) => t.id, 'test')
          .selectFts5Highlight('posts_fts', 0,
              open: '<mark>', close: '</mark>', alias: 'highlighted_title');
      final sql = q.toSql(params);
      expect(sql, contains('highlight(posts_fts, 0, @p0, @p1) AS highlighted_title'));
      expect(params.values['p0'], '<mark>');
      expect(params.values['p1'], '</mark>');
    });
  });

  group('selectFts5Snippet', () {
    test('default parameters', () {
      final q = SelectQuery(posts)
          .fts5Join('posts_fts', (t) => t.id, 'test')
          .selectFts5Snippet('posts_fts', 1);
      final sql = q.toSql(params);
      // SELECT fragments render before WHERE
      expect(
        sql,
        contains('snippet(posts_fts, 1, @p0, @p1, @p2, 64) AS snippet'),
      );
      expect(params.values['p0'], '<b>');
      expect(params.values['p1'], '</b>');
      expect(params.values['p2'], '...');
    });

    test('custom parameters', () {
      final q = SelectQuery(posts)
          .fts5Join('posts_fts', (t) => t.id, 'test')
          .selectFts5Snippet('posts_fts', 0,
              open: '[', close: ']', ellipsis: '…', tokens: 32, alias: 'excerpt');
      final sql = q.toSql(params);
      expect(sql, contains('snippet(posts_fts, 0, @p0, @p1, @p2, 32) AS excerpt'));
      expect(params.values['p0'], '[');
      expect(params.values['p1'], ']');
      expect(params.values['p2'], '…');
    });
  });

  group('orderByFts5Rank', () {
    test('adds ORDER BY without SELECT', () {
      final q = SelectQuery(posts)
          .fts5Join('posts_fts', (t) => t.id, 'test')
          .orderByFts5Rank('posts_fts');
      expect(
        q.toSql(params),
        'SELECT posts.* FROM posts '
        'JOIN posts_fts ON posts.id = posts_fts.rowid '
        'WHERE posts_fts MATCH @p0 '
        'ORDER BY bm25(posts_fts)',
      );
    });

    test('with weights', () {
      final q = SelectQuery(posts)
          .fts5Join('posts_fts', (t) => t.id, 'test')
          .orderByFts5Rank('posts_fts', weights: [5.0, 1.0]);
      expect(
        q.toSql(params),
        'SELECT posts.* FROM posts '
        'JOIN posts_fts ON posts.id = posts_fts.rowid '
        'WHERE posts_fts MATCH @p0 '
        'ORDER BY bm25(posts_fts, 5.0, 1.0)',
      );
    });
  });

  group('fts5JoinOnRowid', () {
    test('renders JOIN on implicit rowid + WHERE MATCH', () {
      final q = SelectQuery(posts)
          .fts5JoinOnRowid('posts_fts', 'database optimization');
      expect(
        q.toSql(params),
        'SELECT posts.* FROM posts '
        'JOIN posts_fts ON posts.rowid = posts_fts.rowid '
        'WHERE posts_fts MATCH @p0',
      );
      expect(params.values, {'p0': 'database optimization'});
    });

    test('composes with selectFts5Rank', () {
      final q = SelectQuery(posts)
          .fts5JoinOnRowid('posts_fts', 'test')
          .selectFts5Rank('posts_fts', weights: [10.0, 1.0]);
      expect(
        q.toSql(params),
        'SELECT posts.*, bm25(posts_fts, 10.0, 1.0) AS rank '
        'FROM posts '
        'JOIN posts_fts ON posts.rowid = posts_fts.rowid '
        'WHERE posts_fts MATCH @p0 '
        'ORDER BY bm25(posts_fts, 10.0, 1.0)',
      );
    });

    test('composes with selectFts5Highlight', () {
      final q = SelectQuery(posts)
          .fts5JoinOnRowid('posts_fts', 'test')
          .selectFts5Highlight('posts_fts', 0);
      final sql = q.toSql(params);
      expect(sql, contains('JOIN posts_fts ON posts.rowid = posts_fts.rowid'));
      expect(sql, contains('highlight(posts_fts, 0,'));
    });
  });

  group('combined FTS5', () {
    test('fts5Join + rank + highlight + snippet', () {
      final q = SelectQuery(posts)
          .fts5Join('posts_fts', (t) => t.id, 'database')
          .selectFts5Rank('posts_fts', weights: [10.0, 1.0])
          .selectFts5Highlight('posts_fts', 0)
          .selectFts5Snippet('posts_fts', 1, tokens: 32);
      final sql = q.toSql(params);
      expect(sql, contains('bm25(posts_fts, 10.0, 1.0) AS rank'));
      expect(sql, contains('highlight(posts_fts, 0,'));
      expect(sql, contains('snippet(posts_fts, 1,'));
      expect(sql, contains('JOIN posts_fts ON posts.id = posts_fts.rowid'));
      expect(sql, contains('posts_fts MATCH'));
      expect(sql, contains('ORDER BY bm25(posts_fts, 10.0, 1.0)'));
    });

    test('all values are parameterized', () {
      final q = SelectQuery(posts)
          .fts5Join('posts_fts', (t) => t.id, 'search term')
          .selectFts5Rank('posts_fts');
      q.toSql(params);
      expect(params.values.containsValue('search term'), isTrue);
    });
  });
}
