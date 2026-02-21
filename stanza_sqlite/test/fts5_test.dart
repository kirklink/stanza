import 'package:stanza/stanza.dart';
import 'package:stanza_sqlite/stanza_sqlite.dart';
import 'package:test/test.dart';

// -- Minimal test fixtures --

class _Post {
  final int id;
  final String title;
  final String body;

  _Post({required this.id, required this.title, required this.body});
}

class _PostTable extends TableDescriptor<_Post> {
  @override
  String get tableName => 'posts';

  final id = const IntColumn('id', 'posts');
  final title = const StringColumn('title', 'posts');
  final body = const StringColumn('body', 'posts');

  @override
  List<Column> get columns => [id, title, body];

  @override
  Column get primaryKey => id;

  @override
  _Post fromRow(Map<String, dynamic> row) => _Post(
        id: row['id'] as int,
        title: row['title'] as String,
        body: row['body'] as String,
      );
}

// -- TEXT PK fixture --

class _Article {
  final String slug;
  final String title;
  final String content;

  _Article({required this.slug, required this.title, required this.content});
}

class _ArticleTable extends TableDescriptor<_Article> {
  @override
  String get tableName => 'articles';

  final slug = const StringColumn('slug', 'articles');
  final title = const StringColumn('title', 'articles');
  final content = const StringColumn('content', 'articles');

  @override
  List<Column> get columns => [slug, title, content];

  @override
  Column get primaryKey => slug;

  @override
  _Article fromRow(Map<String, dynamic> row) => _Article(
        slug: row['slug'] as String,
        title: row['title'] as String,
        content: row['content'] as String,
      );
}

const _postsFts = Fts5Index(
  sourceTable: 'posts',
  columns: ['title', 'body'],
  contentRowid: 'id',
);

const _postsFtsTokenized = Fts5Index(
  sourceTable: 'posts',
  columns: ['title', 'body'],
  contentRowid: 'id',
  tokenize: 'porter unicode61',
);

const _postsFtsCustomName = Fts5Index(
  sourceTable: 'posts',
  columns: ['title', 'body'],
  contentRowid: 'id',
  tableName: 'my_search_index',
);

/// Builds a query and executes it as raw SQL via [rawExecute],
/// returning raw rows (needed for queries with extra projections like rank).
Future<QueryResult<Never>> _executeRaw(
  StanzaSqlite db,
  SelectQuery query,
) async {
  final params = db.createParameterCollector();
  final sql = query.toSql(params);
  return db.rawExecute(sql, parameters: params.values);
}

void main() {
  group('Fts5Index', () {
    test('default table name is sourceTable_fts', () {
      expect(_postsFts.tableName, 'posts_fts');
    });

    test('custom table name', () {
      expect(_postsFtsCustomName.tableName, 'my_search_index');
    });
  });

  group('SqliteDdl.createFts5Table', () {
    test('basic FTS5 table', () {
      expect(
        SqliteDdl.createFts5Table(_postsFts),
        "CREATE VIRTUAL TABLE posts_fts USING fts5("
        "title, body, content='posts', content_rowid='id');",
      );
    });

    test('with tokenizer', () {
      expect(
        SqliteDdl.createFts5Table(_postsFtsTokenized),
        "CREATE VIRTUAL TABLE posts_fts USING fts5("
        "title, body, content='posts', content_rowid='id', "
        "tokenize='porter unicode61');",
      );
    });

    test('custom table name', () {
      expect(
        SqliteDdl.createFts5Table(_postsFtsCustomName),
        "CREATE VIRTUAL TABLE my_search_index USING fts5("
        "title, body, content='posts', content_rowid='id');",
      );
    });
  });

  group('SqliteDdl.createFts5Triggers', () {
    test('generates three triggers', () {
      final triggers = SqliteDdl.createFts5Triggers(_postsFts);
      expect(triggers, hasLength(3));
    });

    test('INSERT trigger', () {
      final triggers = SqliteDdl.createFts5Triggers(_postsFts);
      expect(
        triggers[0],
        'CREATE TRIGGER posts_fts_ai AFTER INSERT ON posts BEGIN '
        'INSERT INTO posts_fts(rowid, title, body) '
        'VALUES (new.id, new.title, new.body); END;',
      );
    });

    test('DELETE trigger uses FTS5 delete syntax', () {
      final triggers = SqliteDdl.createFts5Triggers(_postsFts);
      expect(
        triggers[1],
        'CREATE TRIGGER posts_fts_ad AFTER DELETE ON posts BEGIN '
        "INSERT INTO posts_fts(posts_fts, rowid, title, body) "
        "VALUES ('delete', old.id, old.title, old.body); END;",
      );
    });

    test('UPDATE trigger deletes then inserts', () {
      final triggers = SqliteDdl.createFts5Triggers(_postsFts);
      expect(triggers[2], contains('AFTER UPDATE'));
      expect(triggers[2], contains("VALUES ('delete', old.id"));
      expect(triggers[2], contains('VALUES (new.id'));
    });
  });

  group('SqliteDdl.dropFts5Table', () {
    test('drops triggers then table', () {
      final stmts = SqliteDdl.dropFts5Table(_postsFts);
      expect(stmts, hasLength(4));
      expect(stmts[0], 'DROP TRIGGER IF EXISTS posts_fts_ai;');
      expect(stmts[1], 'DROP TRIGGER IF EXISTS posts_fts_ad;');
      expect(stmts[2], 'DROP TRIGGER IF EXISTS posts_fts_au;');
      expect(stmts[3], 'DROP TABLE IF EXISTS posts_fts;');
    });
  });

  group('FTS5 integration (in-memory SQLite)', () {
    late StanzaSqlite db;
    late _PostTable posts;

    setUp(() async {
      db = StanzaSqlite.memory();
      posts = _PostTable();

      // Create content table
      await db.rawExecute('''
        CREATE TABLE posts (
          id INTEGER PRIMARY KEY,
          title TEXT NOT NULL,
          body TEXT NOT NULL
        )
      ''');

      // Create FTS5 table and triggers
      await db.rawExecute(SqliteDdl.createFts5Table(_postsFts));
      for (final trigger in SqliteDdl.createFts5Triggers(_postsFts)) {
        await db.rawExecute(trigger);
      }

      // Seed data
      await db.rawExecute(
        "INSERT INTO posts (title, body) VALUES "
        "('Database Optimization', 'Learn about query optimization techniques for faster database performance'), "
        "('Web Development', 'Modern web development with JavaScript frameworks and tools'), "
        "('Database Design', 'Best practices for database schema design and normalization')",
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('MATCH returns matching rows', () async {
      final result = await db.execute(
        SelectQuery(posts).fts5Join('posts_fts', (t) => t.id, 'database'),
      );
      expect(result.length, 2);
      final titles = result.entities.map((p) => p.title).toSet();
      expect(titles, contains('Database Optimization'));
      expect(titles, contains('Database Design'));
    });

    test('non-matching MATCH returns empty', () async {
      final result = await db.execute(
        SelectQuery(posts).fts5Join('posts_fts', (t) => t.id, 'nonexistent'),
      );
      expect(result.isEmpty, isTrue);
    });

    test('bm25 ranking returns rank column', () async {
      final result = await _executeRaw(
        db,
        SelectQuery(posts)
            .fts5Join('posts_fts', (t) => t.id, 'database')
            .selectFts5Rank('posts_fts'),
      );
      expect(result.rows, hasLength(2));
      for (final row in result.rows) {
        expect(row.containsKey('rank'), isTrue);
        expect(row['rank'], isA<num>());
      }
    });

    test('highlight returns tags around matches', () async {
      final result = await _executeRaw(
        db,
        SelectQuery(posts)
            .fts5Join('posts_fts', (t) => t.id, 'database')
            .selectFts5Highlight('posts_fts', 0),
      );
      expect(result.rows, isNotEmpty);
      final headline = result.rows.first['headline'] as String;
      expect(headline, contains('<b>'));
      expect(headline, contains('</b>'));
    });

    test('highlight with custom tags', () async {
      final result = await _executeRaw(
        db,
        SelectQuery(posts)
            .fts5Join('posts_fts', (t) => t.id, 'database')
            .selectFts5Highlight('posts_fts', 0,
                open: '<mark>', close: '</mark>'),
      );
      expect(result.rows, isNotEmpty);
      final headline = result.rows.first['headline'] as String;
      expect(headline, contains('<mark>'));
      expect(headline, contains('</mark>'));
    });

    test('snippet returns excerpt', () async {
      final result = await _executeRaw(
        db,
        SelectQuery(posts)
            .fts5Join('posts_fts', (t) => t.id, 'optimization')
            .selectFts5Snippet('posts_fts', 1, tokens: 10),
      );
      expect(result.rows, isNotEmpty);
      final snippet = result.rows.first['snippet'] as String;
      expect(snippet, contains('<b>'));
    });

    test('trigger syncs INSERT', () async {
      await db.rawExecute(
        "INSERT INTO posts (title, body) VALUES "
        "('SQLite Guide', 'A complete guide to SQLite database')",
      );
      final result = await db.execute(
        SelectQuery(posts).fts5Join('posts_fts', (t) => t.id, 'SQLite'),
      );
      expect(result.length, 1);
      expect(result.entities.first.title, 'SQLite Guide');
    });

    test('trigger syncs DELETE', () async {
      var result = await db.execute(
        SelectQuery(posts).fts5Join('posts_fts', (t) => t.id, 'database'),
      );
      expect(result.length, 2);

      await db.rawExecute("DELETE FROM posts WHERE title = 'Database Design'");

      result = await db.execute(
        SelectQuery(posts).fts5Join('posts_fts', (t) => t.id, 'database'),
      );
      expect(result.length, 1);
      expect(result.entities.first.title, 'Database Optimization');
    });

    test('trigger syncs UPDATE', () async {
      // 'web' initially matches only 'Web Development'
      var result = await db.execute(
        SelectQuery(posts).fts5Join('posts_fts', (t) => t.id, 'web'),
      );
      expect(result.length, 1);

      // Update title and body so 'web' no longer matches
      await db.rawExecute(
        "UPDATE posts SET title = 'Cloud Computing', "
        "body = 'Introduction to cloud infrastructure' "
        "WHERE title = 'Web Development'",
      );

      // 'web' should no longer match anything
      result = await db.execute(
        SelectQuery(posts).fts5Join('posts_fts', (t) => t.id, 'web'),
      );
      expect(result.isEmpty, isTrue);

      // 'cloud' should find the updated post
      final cloudResult = await db.execute(
        SelectQuery(posts).fts5Join('posts_fts', (t) => t.id, 'cloud'),
      );
      expect(cloudResult.length, 1);
      expect(cloudResult.entities.first.title, 'Cloud Computing');
    });
  });

  group('FTS5 with TEXT PK (default contentRowid)', () {
    // -- TEXT PK fixture: articles with a TEXT slug as PK --

    const articlesFts = Fts5Index(
      sourceTable: 'articles',
      columns: ['title', 'content'],
      // Uses the default contentRowid: 'rowid'
    );

    group('DDL generation', () {
      test('uses content_rowid=rowid by default', () {
        expect(
          SqliteDdl.createFts5Table(articlesFts),
          "CREATE VIRTUAL TABLE articles_fts USING fts5("
          "title, content, content='articles', content_rowid='rowid');",
        );
      });

      test('triggers reference new.rowid / old.rowid', () {
        final triggers = SqliteDdl.createFts5Triggers(articlesFts);
        expect(triggers[0], contains('VALUES (new.rowid,'));
        expect(triggers[1], contains("VALUES ('delete', old.rowid,"));
        expect(triggers[2], contains("VALUES ('delete', old.rowid,"));
        expect(triggers[2], contains('VALUES (new.rowid,'));
      });
    });

    group('integration (in-memory SQLite)', () {
      late StanzaSqlite db;
      late _ArticleTable articles;

      setUp(() async {
        db = StanzaSqlite.memory();
        articles = _ArticleTable();

        // Create content table with TEXT primary key
        await db.rawExecute('''
          CREATE TABLE articles (
            slug TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            content TEXT NOT NULL
          )
        ''');

        // Create FTS5 table and triggers (uses implicit rowid)
        await db.rawExecute(SqliteDdl.createFts5Table(articlesFts));
        for (final trigger in SqliteDdl.createFts5Triggers(articlesFts)) {
          await db.rawExecute(trigger);
        }

        // Seed data
        await db.rawExecute(
          "INSERT INTO articles (slug, title, content) VALUES "
          "('db-opt', 'Database Optimization', 'Learn about query optimization techniques'), "
          "('web-dev', 'Web Development', 'Modern web development with frameworks'), "
          "('db-design', 'Database Design', 'Best practices for database schema design')",
        );
      });

      tearDown(() async {
        await db.close();
      });

      test('MATCH via fts5JoinOnRowid returns matching rows', () async {
        final result = await _executeRaw(
          db,
          SelectQuery(articles)
              .fts5JoinOnRowid('articles_fts', 'database'),
        );
        expect(result.rows, hasLength(2));
        final titles = result.rows.map((r) => r['title']).toSet();
        expect(titles, contains('Database Optimization'));
        expect(titles, contains('Database Design'));
      });

      test('non-matching query returns empty', () async {
        final result = await _executeRaw(
          db,
          SelectQuery(articles)
              .fts5JoinOnRowid('articles_fts', 'nonexistent'),
        );
        expect(result.rows, isEmpty);
      });

      test('bm25 ranking works with fts5JoinOnRowid', () async {
        final result = await _executeRaw(
          db,
          SelectQuery(articles)
              .fts5JoinOnRowid('articles_fts', 'database')
              .selectFts5Rank('articles_fts'),
        );
        expect(result.rows, hasLength(2));
        for (final row in result.rows) {
          expect(row.containsKey('rank'), isTrue);
          expect(row['rank'], isA<num>());
        }
      });

      test('highlight works with fts5JoinOnRowid', () async {
        final result = await _executeRaw(
          db,
          SelectQuery(articles)
              .fts5JoinOnRowid('articles_fts', 'database')
              .selectFts5Highlight('articles_fts', 0),
        );
        expect(result.rows, isNotEmpty);
        final headline = result.rows.first['headline'] as String;
        expect(headline, contains('<b>'));
        expect(headline, contains('</b>'));
      });

      test('trigger syncs INSERT', () async {
        await db.rawExecute(
          "INSERT INTO articles (slug, title, content) VALUES "
          "('sqlite-guide', 'SQLite Guide', 'A complete guide to SQLite')",
        );
        final result = await _executeRaw(
          db,
          SelectQuery(articles)
              .fts5JoinOnRowid('articles_fts', 'SQLite'),
        );
        expect(result.rows, hasLength(1));
        expect(result.rows.first['title'], 'SQLite Guide');
      });

      test('trigger syncs DELETE', () async {
        await db.rawExecute(
            "DELETE FROM articles WHERE slug = 'db-design'");
        final result = await _executeRaw(
          db,
          SelectQuery(articles)
              .fts5JoinOnRowid('articles_fts', 'database'),
        );
        expect(result.rows, hasLength(1));
        expect(result.rows.first['title'], 'Database Optimization');
      });

      test('trigger syncs UPDATE', () async {
        await db.rawExecute(
          "UPDATE articles SET title = 'Cloud Computing', "
          "content = 'Introduction to cloud infrastructure' "
          "WHERE slug = 'web-dev'",
        );

        // 'web' should no longer match
        final webResult = await _executeRaw(
          db,
          SelectQuery(articles)
              .fts5JoinOnRowid('articles_fts', 'web'),
        );
        expect(webResult.rows, isEmpty);

        // 'cloud' should match the updated article
        final cloudResult = await _executeRaw(
          db,
          SelectQuery(articles)
              .fts5JoinOnRowid('articles_fts', 'cloud'),
        );
        expect(cloudResult.rows, hasLength(1));
        expect(cloudResult.rows.first['title'], 'Cloud Computing');
      });
    });
  });

  group('SqliteIntrospector.fts5TableExists', () {
    late StanzaSqlite db;

    setUp(() async {
      db = StanzaSqlite.memory();
      await db.rawExecute('''
        CREATE TABLE posts (
          id INTEGER PRIMARY KEY,
          title TEXT NOT NULL,
          body TEXT NOT NULL
        )
      ''');
    });

    tearDown(() async {
      await db.close();
    });

    test('returns false for non-existent table', () async {
      final introspector = SqliteIntrospector(db);
      expect(await introspector.fts5TableExists('posts_fts'), isFalse);
    });

    test('returns true for existing FTS5 table', () async {
      await db.rawExecute(SqliteDdl.createFts5Table(_postsFts));
      final introspector = SqliteIntrospector(db);
      expect(await introspector.fts5TableExists('posts_fts'), isTrue);
    });

    test('returns false for regular table', () async {
      final introspector = SqliteIntrospector(db);
      expect(await introspector.fts5TableExists('posts'), isFalse);
    });
  });
}
