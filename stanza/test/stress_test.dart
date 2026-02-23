// Comprehensive stress tests for the Stanza query builder.
//
// Covers edge cases, malicious input, complex compositions, boundary
// conditions, and adversarial usage patterns.
import 'package:stanza/src/identifier.dart';
import 'package:stanza/stanza.dart';
import 'package:test/test.dart';

import 'helpers.dart';

// -- Additional test entities for stress testing --

class Comment {
  final int id;
  final int postId;
  final int? parentId; // nullable for top-level comments
  final String body;
  final bool approved;
  final double score;
  final DateTime createdAt;

  const Comment({
    required this.id,
    required this.postId,
    this.parentId,
    required this.body,
    required this.approved,
    required this.score,
    required this.createdAt,
  });
}

class $CommentTable extends TableDescriptor<Comment> {
  @override
  String get tableName => 'comments';

  final id = const IntColumn('id', 'comments');
  final postId = const IntColumn('post_id', 'comments');
  final parentId = const IntColumn('parent_id', 'comments');
  final body = const StringColumn('body', 'comments');
  final approved = const BoolColumn('approved', 'comments');
  final score = const DoubleColumn('score', 'comments');
  final createdAt = const DateTimeColumn('created_at', 'comments');

  @override
  List<Column> get columns =>
      [id, postId, parentId, body, approved, score, createdAt];

  @override
  Column get primaryKey => id;

  @override
  Comment fromRow(Map<String, dynamic> row) => Comment(
        id: row['id'] as int,
        postId: row['post_id'] as int,
        parentId: row['parent_id'] as int?,
        body: row['body'] as String,
        approved: row['approved'] as bool,
        score: row['score'] as double,
        createdAt: row['created_at'] as DateTime,
      );
}

void main() {
  late $UserTable users;
  late $PostTable posts;
  late $CommentTable comments;
  late ParameterCollector params;

  setUp(() {
    users = $UserTable();
    posts = $PostTable();
    comments = $CommentTable();
    params = ParameterCollector();
  });

  // =========================================================================
  // SQL INJECTION & MALICIOUS INPUT
  // =========================================================================
  group('SQL injection resistance', () {
    test('string value with single quotes is parameterized', () {
      final q = SelectQuery(users)
          .where((t) => t.name.equals("O'Brien"));
      final sql = q.toSql(params);
      expect(sql, isNot(contains("O'Brien")));
      expect(sql, contains('@p0'));
      expect(params.values['p0'], "O'Brien");
    });

    test('string value with double quotes is parameterized', () {
      final q = SelectQuery(users)
          .where((t) => t.name.equals('He said "hello"'));
      expect(q.toSql(params), isNot(contains('"hello"')));
      expect(params.values['p0'], 'He said "hello"');
    });

    test('SQL comment injection in value is parameterized', () {
      final q = SelectQuery(users)
          .where((t) => t.email.equals("admin'--"));
      expect(q.toSql(params), isNot(contains("--")));
      expect(params.values['p0'], "admin'--");
    });

    test('semicolon injection in value is parameterized', () {
      final q = SelectQuery(users)
          .where((t) => t.name.equals("'; DROP TABLE users; --"));
      final sql = q.toSql(params);
      expect(sql, isNot(contains('DROP')));
      expect(sql, isNot(contains(';')));
      expect(params.values['p0'], "'; DROP TABLE users; --");
    });

    test('UNION injection in value is parameterized', () {
      final q = SelectQuery(users).where(
        (t) => t.email.equals("' UNION SELECT * FROM passwords --"),
      );
      final sql = q.toSql(params);
      expect(sql, isNot(contains('UNION')));
      expect(sql, isNot(contains('passwords')));
    });

    test('null byte injection in value is parameterized', () {
      final q = SelectQuery(users)
          .where((t) => t.name.equals("admin\x00"));
      expect(q.toSql(params), contains('@p0'));
      expect(params.values['p0'], "admin\x00");
    });

    test('backslash injection in value is parameterized', () {
      final q = SelectQuery(users)
          .where((t) => t.name.equals(r"test\'injection"));
      expect(q.toSql(params), contains('@p0'));
      expect(params.values['p0'], r"test\'injection");
    });

    test('LIKE pattern with wildcards is parameterized, not interpolated', () {
      final q = SelectQuery(users)
          .where((t) => t.email.like("admin%'--"));
      final sql = q.toSql(params);
      expect(sql, contains('LIKE @p0'));
      expect(params.values['p0'], "admin%'--");
    });

    test('INSERT with malicious string values is parameterized', () {
      final q = InsertQuery(users).values({
        'email': "'; DROP TABLE users;--",
        'name': "Robert'); DROP TABLE Students;--",
      });
      final sql = q.toSql(params);
      expect(sql, isNot(contains('DROP')));
      expect(params.values['p0'], "'; DROP TABLE users;--");
      expect(params.values['p1'], "Robert'); DROP TABLE Students;--");
    });

    test('UPDATE with malicious string values is parameterized', () {
      final q = UpdateQuery(users, {
        'name': "admin'-- OR 1=1",
      }).where((t) => t.id.equals(1));
      final sql = q.toSql(params);
      expect(sql, isNot(contains("OR 1=1")));
      expect(params.values['p0'], "admin'-- OR 1=1");
    });

    test('full-text search with malicious query is parameterized', () {
      final q = SelectQuery(posts)
          .where((t) => t.body.fullTextMatches("'; DROP TABLE posts;--"));
      final sql = q.toSql(params);
      expect(sql, isNot(contains('DROP')));
      expect(params.values['p0'], "'; DROP TABLE posts;--");
    });

    test('trigram similarity with injection attempt is parameterized', () {
      final q = SelectQuery(users)
          .where((t) => t.name.isSimilarTo("' OR '1'='1"));
      final sql = q.toSql(params);
      expect(sql, isNot(contains("OR '1'='1")));
      expect(params.values['p0'], "' OR '1'='1");
    });

    test('Raw expression with named params prevents injection', () {
      final expr = Raw(
        'users.name = :name',
        paramValues: {'name': "'; DELETE FROM users; --"},
      );
      final sql = expr.toSql(params);
      expect(sql, 'users.name = @p0');
      expect(params.values['p0'], "'; DELETE FROM users; --");
    });

    test('batch INSERT with mixed malicious values', () {
      final q = InsertQuery(users).valuesList([
        {'email': "normal@test.com", 'name': "Normal"},
        {'email': "evil@test.com'; DROP TABLE users;--", 'name': "<script>"},
        {'email': "test@test.com", 'name': "O'Malley"},
      ]);
      final sql = q.toSql(params);
      expect(sql, isNot(contains('DROP')));
      expect(sql, isNot(contains('<script>')));
      // All values should be parameterized
      expect(params.values.length, 6);
    });

    test('upsert ON CONFLICT with malicious update values', () {
      final q = InsertQuery(users)
          .values({'email': 'test@test.com', 'name': 'test'})
          .onConflict(
            target: [users.email],
            doUpdate: {'name': "'; DROP TABLE users;--"},
          );
      final sql = q.toSql(params);
      expect(sql, isNot(contains('DROP')));
    });

    test('isIn with malicious list values', () {
      final q = SelectQuery(users).where(
        (t) => t.email.isIn([
          "admin'--",
          "' OR 1=1 --",
          "'; DROP TABLE users;--",
        ]),
      );
      final sql = q.toSql(params);
      expect(sql, isNot(contains('DROP')));
      expect(sql, isNot(contains('OR 1=1')));
      expect(params.values.length, 3);
    });
  });

  // =========================================================================
  // IDENTIFIER VALIDATION
  // =========================================================================
  group('identifier validation', () {
    test('rejects identifier with space', () {
      expect(
        () => assertValidIdentifier('users table', 'name'),
        throwsArgumentError,
      );
    });

    test('rejects identifier starting with number', () {
      expect(
        () => assertValidIdentifier('1users', 'name'),
        throwsArgumentError,
      );
    });

    test('rejects identifier with semicolon', () {
      expect(
        () => assertValidIdentifier('users;--', 'name'),
        throwsArgumentError,
      );
    });

    test('rejects identifier with single quote', () {
      expect(
        () => assertValidIdentifier("users'", 'name'),
        throwsArgumentError,
      );
    });

    test('rejects identifier with parentheses', () {
      expect(
        () => assertValidIdentifier('users()', 'name'),
        throwsArgumentError,
      );
    });

    test('rejects empty identifier', () {
      expect(
        () => assertValidIdentifier('', 'name'),
        throwsArgumentError,
      );
    });

    test('rejects identifier with hyphen', () {
      expect(
        () => assertValidIdentifier('my-table', 'name'),
        throwsArgumentError,
      );
    });

    test('rejects identifier with dot', () {
      expect(
        () => assertValidIdentifier('schema.table', 'name'),
        throwsArgumentError,
      );
    });

    test('accepts valid identifier with underscores', () {
      assertValidIdentifier('my_table_name', 'name'); // no throw
    });

    test('accepts single letter', () {
      assertValidIdentifier('x', 'name'); // no throw
    });

    test('accepts underscore-prefixed', () {
      assertValidIdentifier('_private', 'name'); // no throw
    });

    test('accepts uppercase', () {
      assertValidIdentifier('MyTable', 'name'); // no throw
    });

    test('accepts mixed case with numbers', () {
      assertValidIdentifier('Table123', 'name'); // no throw
    });

    test('FTS5 table name with injection is rejected', () {
      expect(
        () => Fts5Match("'; DROP TABLE --", 'query'),
        throwsArgumentError,
      );
    });

    test('FTS5 table name with space is rejected', () {
      expect(
        () => Fts5Match('my fts table', 'query'),
        throwsArgumentError,
      );
    });

    test('fts5Join rejects invalid table name', () {
      expect(
        () => SelectQuery(posts).fts5Join(
          "invalid;name",
          (t) => t.id,
          'query',
        ),
        throwsArgumentError,
      );
    });

    test('fts5JoinOnRowid rejects invalid table name', () {
      expect(
        () => SelectQuery(posts).fts5JoinOnRowid(
          "table'; DROP TABLE posts;--",
          'query',
        ),
        throwsArgumentError,
      );
    });

    test('selectFts5Rank rejects invalid table name', () {
      expect(
        () => SelectQuery(posts).selectFts5Rank("bad name"),
        throwsArgumentError,
      );
    });

    test('selectFts5Highlight rejects invalid table name', () {
      expect(
        () => SelectQuery(posts).selectFts5Highlight("bad;name", 0),
        throwsArgumentError,
      );
    });

    test('selectFts5Snippet rejects invalid table name', () {
      expect(
        () => SelectQuery(posts).selectFts5Snippet("x' OR '1", 0),
        throwsArgumentError,
      );
    });

    test('orderByFts5Rank rejects invalid table name', () {
      expect(
        () => SelectQuery(posts).orderByFts5Rank("DROP TABLE"),
        throwsArgumentError,
      );
    });
  });

  // =========================================================================
  // EXPRESSION COMPOSITION EDGE CASES
  // =========================================================================
  group('deeply nested expression trees', () {
    test('10-level deep AND chain', () {
      Expression expr = Comparison('a', '=', 0);
      for (var i = 1; i <= 10; i++) {
        expr = expr & Comparison('a', '=', i);
      }
      final sql = expr.toSql(params);
      expect(params.values.length, 11);
      // Should have correct number of AND operations
      expect('AND'.allMatches(sql).length, 10);
    });

    test('10-level deep OR chain', () {
      Expression expr = Comparison('a', '=', 0);
      for (var i = 1; i <= 10; i++) {
        expr = expr | Comparison('a', '=', i);
      }
      final sql = expr.toSql(params);
      expect(params.values.length, 11);
      expect('OR'.allMatches(sql).length, 10);
    });

    test('alternating AND/OR creates correct nesting', () {
      final a = Comparison('x', '=', 1);
      final b = Comparison('y', '=', 2);
      final c = Comparison('z', '=', 3);
      final d = Comparison('w', '=', 4);
      // ((a AND b) OR c) AND d
      final expr = ((a & b) | c) & d;
      final sql = expr.toSql(params);
      expect(sql, '(((x = @p0 AND y = @p1) OR z = @p2) AND w = @p3)');
    });

    test('NOT of AND of OR', () {
      final a = Comparison('x', '=', 1);
      final b = Comparison('y', '=', 2);
      final c = Comparison('z', '=', 3);
      final expr = Not((a | b) & c);
      final sql = expr.toSql(params);
      expect(sql, 'NOT (((x = @p0 OR y = @p1) AND z = @p2))');
    });

    test('double NOT', () {
      final a = Comparison('x', '=', 1);
      final expr = Not(Not(a));
      expect(expr.toSql(params), 'NOT (NOT (x = @p0))');
    });

    test('triple NOT', () {
      final a = Comparison('x', '=', 1);
      final expr = Not(Not(Not(a)));
      expect(expr.toSql(params), 'NOT (NOT (NOT (x = @p0)))');
    });

    test('AND with IsNull on both sides', () {
      final expr = IsNull('a') & IsNull('b');
      final sql = expr.toSql(params);
      expect(sql, '(a IS NULL AND b IS NULL)');
      expect(params.values, isEmpty); // no params for IS NULL
    });

    test('OR of NOT expressions', () {
      final expr = Not(IsNull('a')) | Not(IsNull('b'));
      final sql = expr.toSql(params);
      expect(sql, '(NOT (a IS NULL) OR NOT (b IS NULL))');
    });

    test('between AND null check', () {
      final expr = Between('age', 18, 65) & IsNotNull('email');
      final sql = expr.toSql(params);
      expect(sql, '(age BETWEEN @p0 AND @p1 AND email IS NOT NULL)');
    });

    test('complex tree with every expression type', () {
      // Combine Comparison, And, Or, Not, InList, IsNull, IsNotNull, Between, Like
      final expr = (Comparison('a', '=', 1) &
              Like('b', '%test%', caseSensitive: true)) |
          (Not(IsNull('c')) & Between('d', 10, 20)) |
          InList('e', [1, 2, 3]) |
          NotInList('f', ['x', 'y']);
      final sql = expr.toSql(params);
      // Verify all parts are present
      expect(sql, contains('a = @p'));
      expect(sql, contains('LIKE @p'));
      expect(sql, contains('NOT (c IS NULL)'));
      expect(sql, contains('BETWEEN @p'));
      expect(sql, contains('IN (@p'));
      expect(sql, contains('NOT IN (@p'));
    });
  });

  group('InList / NotInList edge cases', () {
    test('single element InList', () {
      final expr = InList('id', [42]);
      expect(expr.toSql(params), 'id IN (@p0)');
      expect(params.values, {'p0': 42});
    });

    test('empty InList generates empty parentheses', () {
      final expr = InList('id', []);
      // Edge case: IN () is invalid SQL, but the builder should still render it
      // for the caller to handle. This documents current behavior.
      expect(expr.toSql(params), 'id IN ()');
      expect(params.values, isEmpty);
    });

    test('InList with null values', () {
      final expr = InList('status', [null, 'active', null]);
      final sql = expr.toSql(params);
      expect(sql, 'status IN (@p0, @p1, @p2)');
      expect(params.values, {'p0': null, 'p1': 'active', 'p2': null});
    });

    test('NotInList with single element', () {
      final expr = NotInList('role', ['banned']);
      expect(expr.toSql(params), 'role NOT IN (@p0)');
    });

    test('large InList (100 elements)', () {
      final values = List.generate(100, (i) => i);
      final expr = InList('id', values);
      final sql = expr.toSql(params);
      expect(params.values.length, 100);
      // Verify all placeholders are present
      for (var i = 0; i < 100; i++) {
        expect(sql, contains('@p$i'));
      }
    });

    test('InList with mixed types', () {
      // Values are Object? so mixed types are allowed at runtime
      final expr = InList('data', [1, 'two', 3.0, true, null]);
      expr.toSql(params);
      expect(params.values.length, 5);
      expect(params.values['p0'], 1);
      expect(params.values['p1'], 'two');
      expect(params.values['p2'], 3.0);
      expect(params.values['p3'], true);
      expect(params.values['p4'], null);
    });
  });

  group('Raw expression edge cases', () {
    test('Raw with no params', () {
      final expr = Raw('1 = 1');
      expect(expr.toSql(params), '1 = 1');
      expect(params.values, isEmpty);
    });

    test('Raw with empty paramValues map', () {
      final expr = Raw('1 = 1', paramValues: {});
      expect(expr.toSql(params), '1 = 1');
      expect(params.values, isEmpty);
    });

    test('Raw with multiple occurrences of same placeholder', () {
      final expr = Raw(
        ':val > 0 AND :val < 100',
        paramValues: {'val': 50},
      );
      final sql = expr.toSql(params);
      // Both :val should be replaced with the same @p0
      expect(sql, '@p0 > 0 AND @p0 < 100');
      expect(params.values.length, 1);
    });

    test('Raw with placeholder-like text but no params', () {
      final expr = Raw('column :> value');
      expect(expr.toSql(params), 'column :> value');
    });

    test('Raw combined with typed expressions via &', () {
      final raw = Raw('custom_fn(x) > 0');
      final typed = Comparison('users.id', '>', 5);
      final expr = raw & typed;
      final sql = expr.toSql(params);
      expect(sql, '(custom_fn(x) > 0 AND users.id > @p0)');
    });
  });

  // =========================================================================
  // PARAMETER COLLECTOR EDGE CASES
  // =========================================================================
  group('ParameterCollector stress', () {
    test('hundreds of parameters keep correct numbering', () {
      for (var i = 0; i < 500; i++) {
        final placeholder = params.add('value_$i');
        expect(placeholder, '@p$i');
      }
      expect(params.length, 500);
      expect(params.values['p0'], 'value_0');
      expect(params.values['p499'], 'value_499');
    });

    test('SQLite prefix produces :pN format', () {
      final sqliteParams = ParameterCollector(placeholderPrefix: ':');
      expect(sqliteParams.add('test'), ':p0');
      expect(sqliteParams.add(42), ':p1');
      expect(sqliteParams.values, {'p0': 'test', 'p1': 42});
    });

    test('values map is unmodifiable', () {
      params.add('test');
      expect(
        () => params.values['inject'] = 'bad',
        throwsUnsupportedError,
      );
    });

    test('null value is stored correctly', () {
      params.add(null);
      expect(params.values['p0'], isNull);
      expect(params.values.containsKey('p0'), isTrue);
    });

    test('various value types preserved', () {
      params.add(42);
      params.add(3.14);
      params.add(true);
      params.add('text');
      params.add(null);
      params.add(DateTime(2025));
      expect(params.values['p0'], 42);
      expect(params.values['p1'], 3.14);
      expect(params.values['p2'], true);
      expect(params.values['p3'], 'text');
      expect(params.values['p4'], isNull);
      expect(params.values['p5'], DateTime(2025));
    });

    test('empty string is a valid value', () {
      params.add('');
      expect(params.values['p0'], '');
    });

    test('very long string value', () {
      final longString = 'x' * 100000;
      params.add(longString);
      expect(params.values['p0'], longString);
      expect((params.values['p0'] as String).length, 100000);
    });
  });

  // =========================================================================
  // SELECT QUERY EDGE CASES
  // =========================================================================
  group('SELECT edge cases', () {
    test('limit of 0', () {
      final q = SelectQuery(users).limit(0);
      expect(q.toSql(params), 'SELECT users.* FROM users LIMIT 0');
    });

    test('offset of 0', () {
      final q = SelectQuery(users).offset(0);
      expect(q.toSql(params), 'SELECT users.* FROM users OFFSET 0');
    });

    test('very large limit', () {
      final q = SelectQuery(users).limit(999999999);
      expect(q.toSql(params), contains('LIMIT 999999999'));
    });

    test('very large offset', () {
      final q = SelectQuery(users).offset(999999999);
      expect(q.toSql(params), contains('OFFSET 999999999'));
    });

    test('limit and offset of 0', () {
      final q = SelectQuery(users).limit(0).offset(0);
      expect(q.toSql(params), 'SELECT users.* FROM users LIMIT 0 OFFSET 0');
    });

    test('calling limit twice uses last value', () {
      final q = SelectQuery(users).limit(5).limit(10);
      expect(q.toSql(params), 'SELECT users.* FROM users LIMIT 10');
    });

    test('calling offset twice uses last value', () {
      final q = SelectQuery(users).offset(5).offset(20);
      expect(q.toSql(params), 'SELECT users.* FROM users OFFSET 20');
    });

    test('distinct with selectOnly', () {
      final q = SelectQuery(users)
          .distinct()
          .selectOnly((t) => [t.email]);
      expect(
        q.toSql(params),
        'SELECT DISTINCT users.email FROM users',
      );
    });

    test('distinct with selectOnly and aggregate', () {
      final q = SelectQuery(users)
          .distinct()
          .selectOnly((t) => [t.name])
          .selectExpression(users.id.count().as('cnt'));
      final sql = q.toSql(params);
      expect(sql, startsWith('SELECT DISTINCT'));
      expect(sql, contains('COUNT(users.id) AS cnt'));
    });

    test('multiple where calls produce nested AND', () {
      final q = SelectQuery(users)
          .where((t) => t.id.greaterThan(1))
          .where((t) => t.id.lessThan(100))
          .where((t) => t.email.isNotNull());
      final sql = q.toSql(params);
      expect(sql, contains('AND'));
      // 3 wheres → 2 ANDs via reduce
      expect('AND'.allMatches(sql).length, 2);
    });

    test('where with OR inside multiple where calls', () {
      // Multiple .where() calls AND together, but each can contain OR
      final q = SelectQuery(users)
          .where((t) => t.name.equals('A') | t.name.equals('B'))
          .where((t) => t.id.greaterThan(0));
      final sql = q.toSql(params);
      // Should be: ((name = A OR name = B) AND id > 0)
      expect(sql, contains('OR'));
      expect(sql, contains('AND'));
    });

    test('selectOnly with all columns is same as select all', () {
      final q1 = SelectQuery(users);
      final q2 = SelectQuery(users)
          .selectOnly((t) => [t.id, t.email, t.name, t.createdAt]);
      final sql1 = q1.toSql(params);
      final sql2 = q2.toSql(params);
      // q1 uses users.*, q2 lists all columns
      expect(sql1, contains('users.*'));
      expect(sql2, isNot(contains('users.*')));
      expect(sql2, contains('users.id'));
      expect(sql2, contains('users.email'));
      expect(sql2, contains('users.name'));
      expect(sql2, contains('users.created_at'));
    });

    test('multiple orderBy calls chain correctly', () {
      final q = SelectQuery(users)
          .orderBy((t) => t.name.asc())
          .orderBy((t) => t.email.desc())
          .orderBy((t) => t.id.asc());
      expect(
        q.toSql(params),
        contains(
          'ORDER BY users.name ASC, users.email DESC, users.id ASC',
        ),
      );
    });

    test('selectOnly single column', () {
      final q = SelectQuery(users).selectOnly((t) => [t.id]);
      expect(q.toSql(params), 'SELECT users.id FROM users');
    });

    test('multiple selectExpression calls', () {
      final q = SelectQuery(users)
          .selectExpression(users.id.count().as('cnt'))
          .selectExpression(users.id.min().as('min_id'))
          .selectExpression(users.id.max().as('max_id'))
          .selectExpression(users.id.sum().as('total'))
          .selectExpression(users.id.avg().as('average'));
      final sql = q.toSql(params);
      expect(sql, contains('COUNT(users.id) AS cnt'));
      expect(sql, contains('MIN(users.id) AS min_id'));
      expect(sql, contains('MAX(users.id) AS max_id'));
      expect(sql, contains('SUM(users.id) AS total'));
      expect(sql, contains('AVG(users.id) AS average'));
    });

    test('full kitchen sink query', () {
      final q = SelectQuery(posts)
          .selectOnly((t) => [t.authorId, t.title])
          .selectExpression(posts.id.count().as('post_count'))
          .innerJoin(users, (p, u) => p.authorId.equalsColumn(u.id))
          .where((t) => t.createdAt.after(DateTime(2025)))
          .where((t) => t.title.isNotNull())
          .groupBy((t) => [t.authorId, t.title])
          .having((t) => t.id.count().greaterThan(2))
          .orderBy((t) => t.authorId.asc())
          .orderBy((t) => t.title.desc())
          .limit(50)
          .offset(100);
      final sql = q.toSql(params);
      expect(sql, contains('SELECT posts.author_id, posts.title'));
      expect(sql, contains('COUNT(posts.id) AS post_count'));
      expect(sql, contains('INNER JOIN users'));
      expect(sql, contains('WHERE'));
      expect(sql, contains('GROUP BY posts.author_id, posts.title'));
      expect(sql, contains('HAVING COUNT(posts.id) > @p'));
      expect(sql, contains('ORDER BY posts.author_id ASC, posts.title DESC'));
      expect(sql, contains('LIMIT 50'));
      expect(sql, contains('OFFSET 100'));
    });

    test('build() returns correct sql and parameters', () {
      final q = SelectQuery(users)
          .where((t) => t.id.greaterThan(5))
          .where((t) => t.name.like('%test%'))
          .limit(10);
      final result = q.build();
      expect(result.sql, contains('WHERE'));
      expect(result.sql, contains('LIMIT 10'));
      expect(result.parameters.length, 2);
      expect(result.parameters['p0'], 5);
      expect(result.parameters['p1'], '%test%');
    });

    test('query is reusable — build() can be called multiple times', () {
      final q = SelectQuery(users)
          .where((t) => t.id.equals(1));
      final r1 = q.build();
      final r2 = q.build();
      expect(r1.sql, r2.sql);
      expect(r1.parameters, r2.parameters);
    });
  });

  // =========================================================================
  // JOIN EDGE CASES
  // =========================================================================
  group('JOIN edge cases', () {
    test('multiple JOINs on same query', () {
      final q = SelectQuery(comments)
          .innerJoin(posts, (c, p) => c.postId.equalsColumn(p.id))
          .innerJoin(users, (c, u) => c.id.equalsColumn(u.id));
      final sql = q.toSql(params);
      expect(sql, contains('INNER JOIN posts ON'));
      expect(sql, contains('INNER JOIN users ON'));
    });

    test('mixed JOIN types', () {
      final q = SelectQuery(posts)
          .innerJoin(users, (p, u) => p.authorId.equalsColumn(u.id))
          .leftJoin(comments, (p, c) => p.id.equalsColumn(c.postId));
      final sql = q.toSql(params);
      expect(sql, contains('INNER JOIN users ON'));
      expect(sql, contains('LEFT JOIN comments ON'));
    });

    test('JOIN with WHERE clause', () {
      final q = SelectQuery(posts)
          .innerJoin(users, (p, u) => p.authorId.equalsColumn(u.id))
          .where((t) => t.title.like('%dart%'));
      final sql = q.toSql(params);
      expect(sql, contains('INNER JOIN users ON'));
      expect(sql, contains('WHERE posts.title LIKE @p0'));
    });

    test('JOIN preserves correct clause ordering', () {
      final q = SelectQuery(posts)
          .where((t) => t.id.greaterThan(0))
          .innerJoin(users, (p, u) => p.authorId.equalsColumn(u.id))
          .limit(10);
      final sql = q.toSql(params);
      // JOIN should come before WHERE in the SQL
      final joinIdx = sql.indexOf('INNER JOIN');
      final whereIdx = sql.indexOf('WHERE');
      final limitIdx = sql.indexOf('LIMIT');
      expect(joinIdx, lessThan(whereIdx));
      expect(whereIdx, lessThan(limitIdx));
    });

    test('three-way join', () {
      final q = SelectQuery(comments)
          .innerJoin(posts, (c, p) => c.postId.equalsColumn(p.id))
          .innerJoin(users, (c, u) => c.id.equalsColumn(u.id))
          .leftJoin(comments, (c, c2) => c.parentId.equalsColumn(c2.id));
      final sql = q.toSql(params);
      expect('JOIN'.allMatches(sql).length, 3);
    });
  });

  // =========================================================================
  // INSERT EDGE CASES
  // =========================================================================
  group('INSERT edge cases', () {
    test('throws on no rows', () {
      final q = InsertQuery(users);
      expect(() => q.toSql(params), throwsStateError);
    });

    test('single row with single column', () {
      final q = InsertQuery(users).values({'email': 'a@b.com'});
      expect(
        q.toSql(params),
        'INSERT INTO users (email) VALUES (@p0)',
      );
    });

    test('batch insert with many rows', () {
      final rows = List.generate(
        50,
        (i) => <String, dynamic>{'email': 'user$i@test.com', 'name': 'User $i'},
      );
      final q = InsertQuery(users).valuesList(rows);
      final sql = q.toSql(params);
      expect(params.values.length, 100); // 50 rows * 2 columns
      // Should have 50 value groups
      expect('VALUES'.allMatches(sql).length, 1);
      // Count commas between value groups (49 for 50 rows)
      final valuesPart = sql.substring(sql.indexOf('VALUES') + 6);
      expect('), ('.allMatches(valuesPart).length, 49);
    });

    test('insert with null value', () {
      final q = InsertQuery(users).values({
        'email': 'test@test.com',
        'name': null,
      });
      final sql = q.toSql(params);
      expect(sql, contains('@p0'));
      expect(sql, contains('@p1'));
      expect(params.values['p1'], isNull);
    });

    test('values followed by valuesList appends all rows', () {
      final q = InsertQuery(users)
          .values({'email': 'first@test.com', 'name': 'First'})
          .valuesList([
        {'email': 'second@test.com', 'name': 'Second'},
        {'email': 'third@test.com', 'name': 'Third'},
      ]);
      q.toSql(params);
      expect(params.values.length, 6); // 3 rows * 2 cols
    });

    test('onConflict with multiple target columns', () {
      final q = InsertQuery(users)
          .values({'email': 'a@b.com', 'name': 'Test'})
          .onConflictDoNothing(target: [users.email, users.name]);
      final sql = q.toSql(params);
      expect(sql, contains('ON CONFLICT (email, name) DO NOTHING'));
    });

    test('onConflict DO UPDATE with multiple columns', () {
      final q = InsertQuery(users)
          .values({'email': 'a@b.com', 'name': 'Test'})
          .onConflict(
            target: [users.email],
            doUpdate: {'name': 'Updated', 'created_at': DateTime(2025)},
          );
      final sql = q.toSql(params);
      expect(sql, contains('DO UPDATE SET'));
      expect(sql, contains('name = @p'));
      expect(sql, contains('created_at = @p'));
    });

    test('insert with RETURNING', () {
      final q = InsertQuery(users)
          .values({'email': 'a@b.com', 'name': 'Test'})
          .returning();
      final sql = q.toSql(params);
      expect(sql, endsWith('RETURNING *'));
    });

    test('upsert with RETURNING', () {
      final q = InsertQuery(users)
          .values({'email': 'a@b.com', 'name': 'Test'})
          .onConflict(
            target: [users.email],
            doUpdate: {'name': 'Updated'},
          )
          .returning();
      final sql = q.toSql(params);
      expect(sql, contains('ON CONFLICT'));
      expect(sql, endsWith('RETURNING *'));
    });

    test('batch insert with upsert', () {
      final q = InsertQuery(users)
          .valuesList([
            {'email': 'a@b.com', 'name': 'A'},
            {'email': 'c@d.com', 'name': 'C'},
          ])
          .onConflictDoNothing(target: [users.email])
          .returning();
      final sql = q.toSql(params);
      expect(sql, contains('VALUES (@p0, @p1), (@p2, @p3)'));
      expect(sql, contains('ON CONFLICT (email) DO NOTHING'));
      expect(sql, contains('RETURNING *'));
    });

    test('insert build() returns correct result', () {
      final q = InsertQuery(users)
          .values({'email': 'a@b.com', 'name': 'Test'})
          .returning();
      final result = q.build();
      expect(result.sql, contains('INSERT INTO'));
      expect(result.sql, contains('RETURNING *'));
      expect(result.parameters.length, 2);
    });
  });

  // =========================================================================
  // UPDATE EDGE CASES
  // =========================================================================
  group('UPDATE edge cases', () {
    test('throws on empty values map', () {
      final q = UpdateQuery(users, <String, dynamic>{})
          .where((t) => t.id.equals(1));
      expect(() => q.toSql(params), throwsStateError);
    });

    test('throws without WHERE unless allowUnsafe', () {
      final q = UpdateQuery(users, {'name': 'X'});
      expect(() => q.toSql(params), throwsStateError);
    });

    test('allowUnsafe without where succeeds', () {
      final q = UpdateQuery(users, {'name': 'X'}).allowUnsafe();
      expect(q.toSql(params), 'UPDATE users SET name = @p0');
    });

    test('allowUnsafe with where still includes WHERE', () {
      final q = UpdateQuery(users, {'name': 'X'})
          .allowUnsafe()
          .where((t) => t.id.equals(1));
      final sql = q.toSql(params);
      expect(sql, contains('WHERE'));
    });

    test('update many columns at once', () {
      final q = UpdateQuery(users, {
        'email': 'new@test.com',
        'name': 'New Name',
        'created_at': DateTime(2025),
      }).where((t) => t.id.equals(1));
      final sql = q.toSql(params);
      expect(sql, contains('SET email = @p0, name = @p1, created_at = @p2'));
      expect(sql, contains('WHERE users.id = @p3'));
    });

    test('update with null value', () {
      final q = UpdateQuery(users, {'name': null})
          .where((t) => t.id.equals(1));
      final sql = q.toSql(params);
      expect(sql, contains('SET name = @p0'));
      expect(params.values['p0'], isNull);
    });

    test('update with multiple where clauses', () {
      final q = UpdateQuery(users, {'name': 'X'})
          .where((t) => t.id.greaterThan(10))
          .where((t) => t.id.lessThan(100))
          .where((t) => t.email.like('%@test.com'));
      final sql = q.toSql(params);
      expect('AND'.allMatches(sql).length, 2);
    });

    test('update with complex where expression', () {
      final q = UpdateQuery(users, {'name': 'X'}).where(
        (t) =>
            (t.email.like('%@old.com') | t.email.like('%@legacy.com')) &
            t.createdAt.before(DateTime(2020)),
      );
      final sql = q.toSql(params);
      expect(sql, contains('OR'));
      expect(sql, contains('AND'));
    });

    test('update with RETURNING', () {
      final q = UpdateQuery(users, {'name': 'X'})
          .where((t) => t.id.equals(1))
          .returning();
      final sql = q.toSql(params);
      expect(sql, endsWith('RETURNING *'));
    });

    test('update build() returns correct result', () {
      final q = UpdateQuery(users, {'name': 'Test'})
          .where((t) => t.id.equals(42));
      final result = q.build();
      expect(result.sql, contains('UPDATE'));
      expect(result.sql, contains('SET'));
      expect(result.sql, contains('WHERE'));
      expect(result.parameters.length, 2);
    });
  });

  // =========================================================================
  // DELETE EDGE CASES
  // =========================================================================
  group('DELETE edge cases', () {
    test('throws without WHERE unless allowUnsafe', () {
      final q = DeleteQuery(users);
      expect(() => q.toSql(params), throwsStateError);
    });

    test('allowUnsafe without where succeeds', () {
      final q = DeleteQuery(users).allowUnsafe();
      expect(q.toSql(params), 'DELETE FROM users');
    });

    test('allowUnsafe with where still includes WHERE', () {
      final q = DeleteQuery(users)
          .allowUnsafe()
          .where((t) => t.id.equals(1));
      final sql = q.toSql(params);
      expect(sql, contains('WHERE'));
    });

    test('delete with multiple where clauses', () {
      final q = DeleteQuery(users)
          .where((t) => t.id.greaterThan(100))
          .where((t) => t.email.like('%@spam.com'))
          .where((t) => t.name.isNull());
      final sql = q.toSql(params);
      expect('AND'.allMatches(sql).length, 2);
    });

    test('delete with complex compound where', () {
      final q = DeleteQuery(users).where(
        (t) =>
            (t.email.like('%@spam.com') & t.createdAt.before(DateTime(2020))) |
            (t.name.isNull() & t.id.lessThan(10)),
      );
      final sql = q.toSql(params);
      expect(sql, contains('OR'));
      expect(sql, contains('AND'));
    });

    test('delete with RETURNING', () {
      final q = DeleteQuery(users)
          .where((t) => t.id.equals(1))
          .returning();
      expect(q.toSql(params), contains('RETURNING *'));
    });

    test('delete build() returns correct result', () {
      final q = DeleteQuery(users).where((t) => t.id.equals(99));
      final result = q.build();
      expect(result.sql, contains('DELETE FROM'));
      expect(result.sql, contains('WHERE'));
      expect(result.parameters, {'p0': 99});
    });
  });

  // =========================================================================
  // SUBQUERY EDGE CASES
  // =========================================================================
  group('subquery edge cases', () {
    test('subquery with no where clause', () {
      final subquery = SelectQuery(users).selectOnly((t) => [t.id]);
      final q = SelectQuery(posts)
          .where((t) => t.authorId.isInQuery(subquery));
      final sql = q.toSql(params);
      expect(sql, contains('IN (SELECT users.id FROM users)'));
      expect(params.values, isEmpty);
    });

    test('subquery with limit and offset', () {
      final subquery = SelectQuery(users)
          .selectOnly((t) => [t.id])
          .orderBy((t) => t.createdAt.desc())
          .limit(10)
          .offset(5);
      final q = SelectQuery(posts)
          .where((t) => t.authorId.isInQuery(subquery));
      final sql = q.toSql(params);
      expect(sql, contains('LIMIT 10 OFFSET 5'));
    });

    test('notInQuery with complex subquery', () {
      final subquery = SelectQuery(users)
          .selectOnly((t) => [t.id])
          .where((t) => t.email.like('%@banned.com'))
          .where((t) => t.createdAt.before(DateTime(2020)));
      final q = SelectQuery(posts)
          .where((t) => t.authorId.notInQuery(subquery));
      final sql = q.toSql(params);
      expect(sql, contains('NOT IN'));
      expect(params.values.length, 2);
    });

    test('isInQuery and notInQuery combined', () {
      final active = SelectQuery(users)
          .selectOnly((t) => [t.id])
          .where((t) => t.email.isNotNull());
      final banned = SelectQuery(users)
          .selectOnly((t) => [t.id])
          .where((t) => t.name.equals('banned'));
      final q = SelectQuery(posts).where(
        (t) =>
            t.authorId.isInQuery(active) & t.authorId.notInQuery(banned),
      );
      final sql = q.toSql(params);
      expect(sql, contains('IN (SELECT'));
      expect(sql, contains('NOT IN (SELECT'));
    });

    test('subquery parameters merge correctly with outer params', () {
      final subquery = SelectQuery(users)
          .selectOnly((t) => [t.id])
          .where((t) => t.email.like('%@vip.com'));
      final q = SelectQuery(posts)
          .where((t) => t.title.contains('important'))
          .where((t) => t.authorId.isInQuery(subquery))
          .where((t) => t.createdAt.after(DateTime(2025)));
      final sql = q.toSql(params);
      // 3 outer params + 1 subquery param but shared collector
      expect(params.values.length, 3);
      expect(sql, contains('@p0'));
      expect(sql, contains('@p1'));
      expect(sql, contains('@p2'));
    });

    test('nested subquery inside another subquery-level composition', () {
      final innerSub = SelectQuery(comments)
          .selectOnly((t) => [t.postId])
          .where((t) => t.approved.isTrue());
      final q = SelectQuery(posts)
          .where((t) => t.id.isInQuery(innerSub))
          .where((t) => t.authorId.greaterThan(0));
      final sql = q.toSql(params);
      expect(sql, contains('IN (SELECT comments.post_id'));
      expect(sql, contains('comments.approved = @p0'));
      expect(sql, contains('posts.author_id > @p1'));
    });
  });

  // =========================================================================
  // AGGREGATE & GROUP BY / HAVING EDGE CASES
  // =========================================================================
  group('aggregate edge cases', () {
    test('CountAll without alias', () {
      const agg = CountAll();
      expect(agg.toSql(), 'COUNT(*)');
      expect(agg.toSelectSql(), 'COUNT(*)');
    });

    test('aggregate without alias uses function call only', () {
      final agg = users.id.count();
      expect(agg.toSelectSql(), 'COUNT(users.id)');
    });

    test('aggregate .as() produces new instance with alias', () {
      final base = users.id.count();
      final aliased = base.as('total');
      expect(base.alias, isNull);
      expect(aliased.alias, 'total');
      expect(aliased.toSelectSql(), 'COUNT(users.id) AS total');
    });

    test('HAVING with between', () {
      final q = SelectQuery(posts)
          .selectOnly((t) => [t.authorId])
          .groupBy((t) => [t.authorId])
          .having((t) => t.id.count().between(5, 50));
      final sql = q.toSql(params);
      expect(sql, contains('HAVING COUNT(posts.id) BETWEEN @p0 AND @p1'));
    });

    test('HAVING with notEquals', () {
      final q = SelectQuery(posts)
          .selectOnly((t) => [t.authorId])
          .groupBy((t) => [t.authorId])
          .having((t) => t.id.count().notEquals(0));
      final sql = q.toSql(params);
      expect(sql, contains('HAVING COUNT(posts.id) != @p0'));
    });

    test('HAVING with equals and lessThanOrEqual combined', () {
      final q = SelectQuery(posts)
          .selectOnly((t) => [t.authorId])
          .groupBy((t) => [t.authorId])
          .having(
            (t) =>
                t.id.count().greaterThanOrEqual(1) &
                t.id.count().lessThanOrEqual(100),
          );
      final sql = q.toSql(params);
      expect(sql, contains('HAVING'));
      expect(sql, contains('>= @p0'));
      expect(sql, contains('<= @p1'));
    });

    test('multiple having calls produce AND', () {
      final q = SelectQuery(posts)
          .selectOnly((t) => [t.authorId])
          .groupBy((t) => [t.authorId])
          .having((t) => t.id.count().greaterThan(0))
          .having((t) => t.id.count().lessThan(1000))
          .having((t) => t.id.sum().greaterThan(10));
      final sql = q.toSql(params);
      expect('AND'.allMatches(sql).length, 2);
    });

    test('GROUP BY with many columns', () {
      final q = SelectQuery(posts)
          .selectOnly((t) => [t.authorId, t.title, t.body, t.createdAt])
          .groupBy((t) => [t.authorId, t.title, t.body, t.createdAt]);
      final sql = q.toSql(params);
      expect(
        sql,
        contains(
          'GROUP BY posts.author_id, posts.title, posts.body, posts.created_at',
        ),
      );
    });

    test('aggregate on different column types', () {
      expect(comments.score.sum().toSql(), 'SUM(comments.score)');
      expect(comments.score.avg().toSql(), 'AVG(comments.score)');
      expect(comments.createdAt.min().toSql(), 'MIN(comments.created_at)');
      expect(comments.createdAt.max().toSql(), 'MAX(comments.created_at)');
      expect(comments.body.count().toSql(), 'COUNT(comments.body)');
    });
  });

  // =========================================================================
  // COLUMN TYPE EDGE CASES
  // =========================================================================
  group('column type edge cases', () {
    test('IntColumn with zero', () {
      final expr = users.id.equals(0);
      expect(expr.toSql(params), 'users.id = @p0');
      expect(params.values['p0'], 0);
    });

    test('IntColumn with negative values', () {
      final expr = users.id.greaterThan(-1);
      expect(params.values.isEmpty, isTrue); // before toSql
      expr.toSql(params);
      expect(params.values['p0'], -1);
    });

    test('IntColumn between with reversed range', () {
      // BETWEEN 100 AND 10 is valid SQL but returns no rows
      final expr = users.id.between(100, 10);
      expect(expr.toSql(params), 'users.id BETWEEN @p0 AND @p1');
      expect(params.values, {'p0': 100, 'p1': 10});
    });

    test('DoubleColumn with zero', () {
      final expr = comments.score.equals(0.0);
      expr.toSql(params);
      expect(params.values['p0'], 0.0);
    });

    test('DoubleColumn with very small value', () {
      final expr = comments.score.greaterThan(0.000001);
      expr.toSql(params);
      expect(params.values['p0'], 0.000001);
    });

    test('DoubleColumn with very large value', () {
      final expr = comments.score.lessThan(1e15);
      expr.toSql(params);
      expect(params.values['p0'], 1e15);
    });

    test('StringColumn startsWith with empty string', () {
      final expr = users.email.startsWith('');
      expr.toSql(params);
      expect(params.values['p0'], '%'); // '' + '%'
    });

    test('StringColumn endsWith with empty string', () {
      final expr = users.email.endsWith('');
      expr.toSql(params);
      expect(params.values['p0'], '%'); // '%' + ''
    });

    test('StringColumn contains with empty string', () {
      final expr = users.email.contains('');
      expr.toSql(params);
      expect(params.values['p0'], '%%'); // '%' + '' + '%'
    });

    test('StringColumn like with empty pattern', () {
      final expr = users.email.like('');
      expr.toSql(params);
      expect(params.values['p0'], '');
    });

    test('StringColumn with LIKE wildcards in startsWith', () {
      // If someone passes '%' as the prefix, it becomes '%%'
      final expr = users.email.startsWith('%');
      expr.toSql(params);
      expect(params.values['p0'], '%%');
    });

    test('StringColumn with underscore in contains', () {
      // Underscore is a LIKE wildcard - it's parameterized so safe
      final expr = users.email.contains('_admin_');
      expr.toSql(params);
      expect(params.values['p0'], '%_admin_%');
    });

    test('BoolColumn equals true/false via base class', () {
      final trueExpr = comments.approved.equals(true);
      final falseExpr = comments.approved.equals(false);
      trueExpr.toSql(params);
      falseExpr.toSql(params);
      expect(params.values['p0'], true);
      expect(params.values['p1'], false);
    });

    test('DateTimeColumn with epoch', () {
      final epoch = DateTime.fromMillisecondsSinceEpoch(0);
      final expr = users.createdAt.after(epoch);
      expr.toSql(params);
      expect(params.values['p0'], epoch);
    });

    test('DateTimeColumn with far future date', () {
      final future = DateTime(9999, 12, 31, 23, 59, 59);
      final expr = users.createdAt.before(future);
      expr.toSql(params);
      expect(params.values['p0'], future);
    });

    test('DateTimeColumn between same date', () {
      final date = DateTime(2025, 6, 15);
      final expr = users.createdAt.between(date, date);
      expr.toSql(params);
      expect(params.values['p0'], date);
      expect(params.values['p1'], date);
    });

    test('Column equalsColumn with same table columns', () {
      // Self-referential column comparison
      final expr = comments.postId.equalsColumn(comments.parentId);
      expect(
        expr.toSql(params),
        'comments.post_id = comments.parent_id',
      );
      expect(params.values, isEmpty);
    });

    test('Column isIn with empty list', () {
      final expr = users.id.isIn([]);
      expect(expr.toSql(params), 'users.id IN ()');
    });

    test('Column notIn with empty list', () {
      final expr = users.id.notIn([]);
      expect(expr.toSql(params), 'users.id NOT IN ()');
    });

    test('Column notEquals with same value', () {
      // Valid SQL: users.id != 5 even if silly with equals + notEquals
      final expr = users.id.equals(5) & users.id.notEquals(5);
      expect(
        expr.toSql(params),
        '(users.id = @p0 AND users.id != @p1)',
      );
    });
  });

  // =========================================================================
  // FTS EDGE CASES
  // =========================================================================
  group('FTS edge cases', () {
    test('all FtsConfig values produce correct config string', () {
      for (final config in FtsConfig.values) {
        final expr = posts.body.fullTextMatches('test', config: config);
        final p = ParameterCollector();
        final sql = expr.toSql(p);
        expect(sql, contains("'${config.value}'"));
      }
    });

    test('all FtsQueryType values produce correct function', () {
      for (final queryType in FtsQueryType.values) {
        final expr = posts.body.fullTextMatches(
          'test',
          queryType: queryType,
        );
        final p = ParameterCollector();
        final sql = expr.toSql(p);
        expect(sql, contains(queryType.functionName));
      }
    });

    test('FTS with empty query string', () {
      final expr = posts.body.fullTextMatches('');
      final sql = expr.toSql(params);
      expect(params.values['p0'], '');
      expect(sql, contains('@p0'));
    });

    test('FTS with special characters in query', () {
      final expr = posts.body.fullTextMatches('hello & world | "exact"');
      final sql = expr.toSql(params);
      expect(params.values['p0'], 'hello & world | "exact"');
      expect(sql, isNot(contains('hello &')));
    });

    test('selectRank with non-default config', () {
      final q = SelectQuery(posts).selectRank(
        (t) => t.body,
        'test',
        config: FtsConfig.french,
        queryType: FtsQueryType.websearch,
        alias: 'custom_rank',
      );
      final sql = q.toSql(params);
      expect(sql, contains("'french'"));
      expect(sql, contains('websearch_to_tsquery'));
      expect(sql, contains('AS custom_rank'));
    });

    test('selectHeadline with all options', () {
      final q = SelectQuery(posts).selectHeadline(
        (t) => t.body,
        'test',
        config: FtsConfig.german,
        queryType: FtsQueryType.phrase,
        options: 'MaxWords=35, MinWords=15',
        alias: 'custom_headline',
      );
      final sql = q.toSql(params);
      expect(sql, contains("'german'"));
      expect(sql, contains('phraseto_tsquery'));
      expect(sql, contains('MaxWords=35, MinWords=15'));
      expect(sql, contains('AS custom_headline'));
    });

    test('selectSimilarity with orderBySimilarity false', () {
      final q = SelectQuery(users)
          .selectSimilarity((t) => t.name, 'test', orderBySimilarity: false);
      final sql = q.toSql(params);
      expect(sql, contains('similarity('));
      expect(sql, isNot(contains('ORDER BY')));
    });

    test('selectSimilarity with custom alias', () {
      final q = SelectQuery(users).selectSimilarity(
        (t) => t.name,
        'test',
        alias: 'sim',
      );
      final sql = q.toSql(params);
      expect(sql, contains('AS sim'));
    });

    test('combined FTS rank + headline + similarity in one query', () {
      final q = SelectQuery(posts)
          .where((t) => t.body.fullTextMatches('optimization'))
          .selectRank((t) => t.body, 'optimization')
          .selectHeadline((t) => t.body, 'optimization');
      final sql = q.toSql(params);
      expect(sql, contains('ts_rank'));
      expect(sql, contains('ts_headline'));
      expect(sql, contains('ORDER BY'));
    });

    test('orderByDistance produces correct SQL', () {
      final q = SelectQuery(users)
          .where((t) => t.name.isSimilarTo('test'))
          .orderByDistance((t) => t.name, 'test');
      final sql = q.toSql(params);
      expect(sql, contains('<->'));
    });

    test('FTS5 join with valid identifier', () {
      final q = SelectQuery(posts)
          .fts5Join('posts_fts', (t) => t.id, 'search term');
      final sqliteParams = ParameterCollector(placeholderPrefix: ':');
      final sql = q.toSql(sqliteParams);
      expect(sql, contains('JOIN posts_fts ON'));
      expect(sql, contains('posts_fts MATCH'));
    });

    test('FTS5 join on rowid', () {
      final q = SelectQuery(posts)
          .fts5JoinOnRowid('posts_fts', 'search term');
      final sqliteParams = ParameterCollector(placeholderPrefix: ':');
      final sql = q.toSql(sqliteParams);
      expect(sql, contains('posts.rowid = posts_fts.rowid'));
      expect(sql, contains('posts_fts MATCH'));
    });

    test('FTS5 rank with weights', () {
      final q = SelectQuery(posts)
          .fts5Join('posts_fts', (t) => t.id, 'query')
          .selectFts5Rank('posts_fts', weights: [10.0, 1.0, 5.0]);
      final sqliteParams = ParameterCollector(placeholderPrefix: ':');
      final sql = q.toSql(sqliteParams);
      expect(sql, contains('bm25(posts_fts, 10.0, 1.0, 5.0)'));
    });

    test('FTS5 highlight with custom markers', () {
      final q = SelectQuery(posts)
          .fts5Join('posts_fts', (t) => t.id, 'query')
          .selectFts5Highlight(
            'posts_fts',
            1,
            open: '<mark>',
            close: '</mark>',
            alias: 'highlighted',
          );
      final sqliteParams = ParameterCollector(placeholderPrefix: ':');
      final sql = q.toSql(sqliteParams);
      expect(sql, contains('highlight(posts_fts, 1'));
      expect(sql, contains('AS highlighted'));
    });

    test('FTS5 snippet with custom parameters', () {
      final q = SelectQuery(posts)
          .fts5Join('posts_fts', (t) => t.id, 'query')
          .selectFts5Snippet(
            'posts_fts',
            0,
            open: '[',
            close: ']',
            ellipsis: '~~~',
            tokens: 16,
            alias: 'snip',
          );
      final sqliteParams = ParameterCollector(placeholderPrefix: ':');
      final sql = q.toSql(sqliteParams);
      expect(sql, contains('snippet(posts_fts, 0'));
      expect(sql, contains('16'));
      expect(sql, contains('AS snip'));
    });

    test('orderByFts5Rank without weights', () {
      final q = SelectQuery(posts)
          .fts5Join('posts_fts', (t) => t.id, 'query')
          .orderByFts5Rank('posts_fts');
      final sqliteParams = ParameterCollector(placeholderPrefix: ':');
      final sql = q.toSql(sqliteParams);
      expect(sql, contains('ORDER BY bm25(posts_fts)'));
    });

    test('orderByFts5Rank with weights', () {
      final q = SelectQuery(posts)
          .fts5Join('posts_fts', (t) => t.id, 'query')
          .orderByFts5Rank('posts_fts', weights: [5.0, 1.0]);
      final sqliteParams = ParameterCollector(placeholderPrefix: ':');
      final sql = q.toSql(sqliteParams);
      expect(sql, contains('ORDER BY bm25(posts_fts, 5.0, 1.0)'));
    });
  });

  // =========================================================================
  // SCHEMA DIFF STRESS TESTS
  // =========================================================================
  group('schema diff stress', () {
    test('table with many columns', () {
      final cols = List.generate(
        20,
        (i) => SchemaColumn(
          name: 'col_$i',
          type: ColumnType(i.isEven ? 'text' : 'integer'),
          nullable: i > 10,
        ),
      );
      final table = SchemaTable(name: 'big_table', columns: cols);
      final ops = SchemaDiff.diff(table, null);
      expect(ops, hasLength(1));
      expect(ops.first, isA<CreateTable>());
      final sql = ops.first.toSql();
      for (var i = 0; i < 20; i++) {
        expect(sql, contains('col_$i'));
      }
    });

    test('adding many columns at once', () {
      final expected = SchemaTable(
        name: 'users',
        columns: [
          const SchemaColumn(name: 'id', type: ColumnType('integer')),
          ...List.generate(
            10,
            (i) => SchemaColumn(
              name: 'new_col_$i',
              type: const ColumnType('text'),
            ),
          ),
        ],
      );
      final actual = SchemaTable(
        name: 'users',
        columns: [
          const SchemaColumn(name: 'id', type: ColumnType('integer')),
        ],
      );
      final ops = SchemaDiff.diff(expected, actual);
      expect(ops, hasLength(10));
      for (final op in ops) {
        expect(op, isA<AddColumn>());
      }
    });

    test('dropping many columns at once', () {
      final expected = SchemaTable(
        name: 'users',
        columns: [
          const SchemaColumn(name: 'id', type: ColumnType('integer')),
        ],
      );
      final actual = SchemaTable(
        name: 'users',
        columns: [
          const SchemaColumn(name: 'id', type: ColumnType('integer')),
          ...List.generate(
            10,
            (i) => SchemaColumn(
              name: 'old_col_$i',
              type: const ColumnType('text'),
            ),
          ),
        ],
      );
      final ops = SchemaDiff.diff(expected, actual);
      expect(ops, hasLength(10));
      for (final op in ops) {
        expect(op, isA<DropColumn>());
        expect(op.toSql(), contains('-- SAFETY'));
      }
    });

    test('simultaneous add, drop, and modify columns', () {
      final expected = SchemaTable(
        name: 'users',
        columns: [
          const SchemaColumn(name: 'id', type: ColumnType('integer')),
          // email changed type
          const SchemaColumn(
            name: 'email',
            type: ColumnType('varchar(255)'),
            nullable: false,
          ),
          // name is new
          const SchemaColumn(name: 'name', type: ColumnType('text')),
          // bio changed nullability
          const SchemaColumn(
            name: 'bio',
            type: ColumnType('text'),
            nullable: false,
          ),
        ],
      );
      final actual = SchemaTable(
        name: 'users',
        columns: [
          const SchemaColumn(name: 'id', type: ColumnType('integer')),
          const SchemaColumn(name: 'email', type: ColumnType('text')),
          // old_col will be dropped
          const SchemaColumn(name: 'old_col', type: ColumnType('text')),
          const SchemaColumn(
            name: 'bio',
            type: ColumnType('text'),
            nullable: true,
          ),
        ],
      );
      final ops = SchemaDiff.diff(expected, actual);
      final types = ops.map((o) => o.runtimeType).toList();
      expect(types, contains(AlterColumnType)); // email type
      expect(types, contains(AlterColumnNullability)); // email + bio nullability
      expect(types, contains(AddColumn)); // name
      expect(types, contains(DropColumn)); // old_col
    });

    test('all serial equivalences', () {
      final pairs = [
        ('serial', 'integer'),
        ('bigserial', 'bigint'),
        ('smallserial', 'smallint'),
      ];
      for (final (serialType, intType) in pairs) {
        final expected = SchemaTable(
          name: 'test',
          columns: [
            SchemaColumn(
              name: 'id',
              type: ColumnType(serialType),
              isSerial: true,
            ),
          ],
        );
        final actual = SchemaTable(
          name: 'test',
          columns: [
            SchemaColumn(
              name: 'id',
              type: ColumnType(intType),
              isSerial: true,
            ),
          ],
        );
        final ops = SchemaDiff.diff(expected, actual);
        expect(ops, isEmpty, reason: '$serialType ≡ $intType');
      }
    });

    test('serial vs non-equivalent type produces change', () {
      final expected = SchemaTable(
        name: 'test',
        columns: [
          const SchemaColumn(
            name: 'id',
            type: ColumnType('serial'),
            isSerial: true,
          ),
        ],
      );
      final actual = SchemaTable(
        name: 'test',
        columns: [
          const SchemaColumn(
            name: 'id',
            type: ColumnType('bigint'),
            isSerial: true,
          ),
        ],
      );
      final ops = SchemaDiff.diff(expected, actual);
      expect(ops, hasLength(1));
      expect(ops.first, isA<AlterColumnType>());
    });

    test('adding and removing constraints simultaneously', () {
      final expected = SchemaTable(
        name: 'users',
        columns: [
          const SchemaColumn(name: 'id', type: ColumnType('integer')),
          const SchemaColumn(name: 'email', type: ColumnType('text')),
        ],
        constraints: [
          const SchemaConstraint(
            name: 'users_pkey',
            kind: ConstraintKind.primaryKey,
            columns: ['id'],
          ),
          const SchemaConstraint(
            name: 'users_email_key',
            kind: ConstraintKind.unique,
            columns: ['email'],
          ),
        ],
      );
      final actual = SchemaTable(
        name: 'users',
        columns: [
          const SchemaColumn(name: 'id', type: ColumnType('integer')),
          const SchemaColumn(name: 'email', type: ColumnType('text')),
        ],
        constraints: [
          const SchemaConstraint(
            name: 'users_pkey',
            kind: ConstraintKind.primaryKey,
            columns: ['id'],
          ),
          // old_constraint will be dropped
          const SchemaConstraint(
            name: 'users_old_key',
            kind: ConstraintKind.unique,
            columns: ['id'],
          ),
        ],
      );
      final ops = SchemaDiff.diff(expected, actual);
      expect(ops.whereType<AddConstraint>(), hasLength(1));
      expect(ops.whereType<DropConstraint>(), hasLength(1));
    });

    test('foreign key constraint with all options', () {
      final sql = const AddConstraint(
        'comments',
        SchemaConstraint(
          name: 'comments_post_id_fkey',
          kind: ConstraintKind.foreignKey,
          columns: ['post_id'],
          referencedTable: 'posts',
          referencedColumn: 'id',
          onDelete: 'SET NULL',
        ),
      ).toSql();
      expect(sql, contains('FOREIGN KEY (post_id)'));
      expect(sql, contains('REFERENCES posts (id)'));
      expect(sql, contains('ON DELETE SET NULL'));
    });

    test('composite primary key', () {
      final table = SchemaTable(
        name: 'user_roles',
        columns: [
          const SchemaColumn(
            name: 'user_id',
            type: ColumnType('integer'),
            nullable: false,
          ),
          const SchemaColumn(
            name: 'role_id',
            type: ColumnType('integer'),
            nullable: false,
          ),
        ],
        constraints: [
          const SchemaConstraint(
            name: 'user_roles_pkey',
            kind: ConstraintKind.primaryKey,
            columns: ['user_id', 'role_id'],
          ),
        ],
      );
      final sql = CreateTable(table).toSql();
      expect(sql, contains('PRIMARY KEY (user_id, role_id)'));
    });

    test('composite unique constraint', () {
      final sql = const AddConstraint(
        'events',
        SchemaConstraint(
          name: 'events_date_venue_key',
          kind: ConstraintKind.unique,
          columns: ['date', 'venue'],
        ),
      ).toSql();
      expect(sql, contains('UNIQUE (date, venue)'));
    });

    test('CreateTable with defaults and NOT NULL', () {
      final table = SchemaTable(
        name: 'settings',
        columns: [
          const SchemaColumn(
            name: 'key',
            type: ColumnType('text'),
            nullable: false,
          ),
          const SchemaColumn(
            name: 'value',
            type: ColumnType('text'),
            defaultValue: "''",
          ),
          const SchemaColumn(
            name: 'active',
            type: ColumnType('boolean'),
            nullable: false,
            defaultValue: 'true',
          ),
        ],
      );
      final sql = CreateTable(table).toSql();
      expect(sql, contains('key text NOT NULL'));
      expect(sql, contains("value text DEFAULT ''"));
      expect(sql, contains('active boolean NOT NULL DEFAULT true'));
    });

    test('DropColumn produces safety comment', () {
      final sql = const DropColumn('sensitive_table', 'pii_column').toSql();
      expect(sql, startsWith('-- SAFETY:'));
      expect(sql, contains('DROP COLUMN pii_column'));
      // Should NOT be executable without removing the comment
      expect(sql, isNot(startsWith('ALTER')));
    });

    test('empty table produces valid CREATE TABLE', () {
      final table = SchemaTable(name: 'empty_table', columns: []);
      final sql = CreateTable(table).toSql();
      expect(sql, contains('CREATE TABLE empty_table'));
    });

    test('diff identical tables with constraints produces no ops', () {
      final table = SchemaTable(
        name: 'users',
        columns: [
          const SchemaColumn(
            name: 'id',
            type: ColumnType('integer'),
            nullable: false,
          ),
          const SchemaColumn(
            name: 'email',
            type: ColumnType('text'),
          ),
        ],
        constraints: [
          const SchemaConstraint(
            name: 'users_pkey',
            kind: ConstraintKind.primaryKey,
            columns: ['id'],
          ),
          const SchemaConstraint(
            name: 'users_email_key',
            kind: ConstraintKind.unique,
            columns: ['email'],
          ),
        ],
      );
      final ops = SchemaDiff.diff(table, table);
      expect(ops, isEmpty);
    });

    test('default change from value to null produces DROP DEFAULT', () {
      final expected = SchemaTable(
        name: 'users',
        columns: [
          const SchemaColumn(name: 'status', type: ColumnType('text')),
        ],
      );
      final actual = SchemaTable(
        name: 'users',
        columns: [
          const SchemaColumn(
            name: 'status',
            type: ColumnType('text'),
            defaultValue: "'active'",
          ),
        ],
      );
      final ops = SchemaDiff.diff(expected, actual);
      expect(ops, hasLength(1));
      expect(ops.first, isA<AlterColumnDefault>());
      final alter = ops.first as AlterColumnDefault;
      expect(alter.newDefault, isNull);
      expect(alter.toSql(), contains('DROP DEFAULT'));
    });

    test('default change from null to value produces SET DEFAULT', () {
      final expected = SchemaTable(
        name: 'users',
        columns: [
          const SchemaColumn(
            name: 'status',
            type: ColumnType('text'),
            defaultValue: "'active'",
          ),
        ],
      );
      final actual = SchemaTable(
        name: 'users',
        columns: [
          const SchemaColumn(name: 'status', type: ColumnType('text')),
        ],
      );
      final ops = SchemaDiff.diff(expected, actual);
      expect(ops, hasLength(1));
      expect(ops.first, isA<AlterColumnDefault>());
      expect(ops.first.toSql(), contains('SET DEFAULT'));
    });
  });

  // =========================================================================
  // COLUMN TYPE MAPPING EDGE CASES
  // =========================================================================
  group('ColumnType edge cases', () {
    test('fromDartType maps all standard types', () {
      expect(ColumnType.fromDartType('int').value, 'integer');
      expect(ColumnType.fromDartType('String').value, 'text');
      expect(ColumnType.fromDartType('bool').value, 'boolean');
      expect(ColumnType.fromDartType('double').value, 'double precision');
      expect(ColumnType.fromDartType('DateTime').value, 'timestamptz');
    });

    test('fromDartType strips nullable suffix', () {
      expect(ColumnType.fromDartType('int?').value, 'integer');
      expect(ColumnType.fromDartType('String?').value, 'text');
      expect(ColumnType.fromDartType('bool?').value, 'boolean');
      expect(ColumnType.fromDartType('double?').value, 'double precision');
      expect(ColumnType.fromDartType('DateTime?').value, 'timestamptz');
    });

    test('fromDartType with serial flag', () {
      expect(ColumnType.fromDartType('int', serial: true).value, 'serial');
    });

    test('fromDartType with unknown type defaults to text', () {
      expect(ColumnType.fromDartType('CustomType').value, 'text');
      expect(ColumnType.fromDartType('Map<String, dynamic>').value, 'text');
    });

    test('fromUdtName maps all postgres types', () {
      expect(ColumnType.fromUdtName('int4').value, 'integer');
      expect(ColumnType.fromUdtName('int2').value, 'smallint');
      expect(ColumnType.fromUdtName('int8').value, 'bigint');
      expect(ColumnType.fromUdtName('float4').value, 'real');
      expect(ColumnType.fromUdtName('float8').value, 'double precision');
      expect(ColumnType.fromUdtName('bool').value, 'boolean');
      expect(ColumnType.fromUdtName('text').value, 'text');
      expect(ColumnType.fromUdtName('timestamptz').value, 'timestamptz');
      expect(ColumnType.fromUdtName('timestamp').value, 'timestamp');
      expect(ColumnType.fromUdtName('date').value, 'date');
      expect(ColumnType.fromUdtName('jsonb').value, 'jsonb');
      expect(ColumnType.fromUdtName('json').value, 'json');
      expect(ColumnType.fromUdtName('uuid').value, 'uuid');
      expect(ColumnType.fromUdtName('numeric').value, 'numeric');
      expect(ColumnType.fromUdtName('bytea').value, 'bytea');
    });

    test('fromUdtName varchar with length', () {
      expect(
        ColumnType.fromUdtName('varchar', charMaxLength: '255').value,
        'varchar(255)',
      );
    });

    test('fromUdtName varchar without length', () {
      expect(ColumnType.fromUdtName('varchar').value, 'varchar');
    });

    test('fromUdtName with unknown type passes through', () {
      expect(ColumnType.fromUdtName('citext').value, 'citext');
      expect(ColumnType.fromUdtName('hstore').value, 'hstore');
    });

    test('isEquivalentTo reflexive', () {
      final ct = const ColumnType('text');
      expect(ct.isEquivalentTo(ct), isTrue);
    });

    test('isEquivalentTo serial equivalences', () {
      expect(
        const ColumnType('serial')
            .isEquivalentTo(const ColumnType('integer')),
        isTrue,
      );
      expect(
        const ColumnType('integer')
            .isEquivalentTo(const ColumnType('serial')),
        isTrue,
      );
      expect(
        const ColumnType('bigserial')
            .isEquivalentTo(const ColumnType('bigint')),
        isTrue,
      );
      expect(
        const ColumnType('smallserial')
            .isEquivalentTo(const ColumnType('smallint')),
        isTrue,
      );
    });

    test('isEquivalentTo non-equivalent types', () {
      expect(
        const ColumnType('text')
            .isEquivalentTo(const ColumnType('integer')),
        isFalse,
      );
      expect(
        const ColumnType('serial')
            .isEquivalentTo(const ColumnType('bigint')),
        isFalse,
      );
    });

    test('equality and hashCode', () {
      final a = const ColumnType('text');
      final b = const ColumnType('text');
      final c = const ColumnType('integer');
      expect(a == b, isTrue);
      expect(a == c, isFalse);
      expect(a.hashCode, b.hashCode);
    });

    test('toString returns value', () {
      expect(const ColumnType('jsonb').toString(), 'jsonb');
    });
  });

  // =========================================================================
  // MIGRATION FILE EDGE CASES
  // =========================================================================
  group('MigrationFileWriter', () {
    test('generateFilename produces correct format', () {
      final filename = MigrationFileWriter.generateFilename(
        now: DateTime.utc(2025, 1, 15, 9, 5, 3),
      );
      expect(filename, '20250115_090503.sql');
    });

    test('generateFilename pads single-digit components', () {
      final filename = MigrationFileWriter.generateFilename(
        now: DateTime.utc(2025, 1, 1, 1, 1, 1),
      );
      expect(filename, '20250101_010101.sql');
    });

    test('generate wraps ops in BEGIN/COMMIT', () {
      final content = MigrationFileWriter.generate([
        const AddColumn(
          'users',
          SchemaColumn(name: 'bio', type: ColumnType('text')),
        ),
      ]);
      expect(content, contains('BEGIN;'));
      expect(content, contains('COMMIT;'));
    });

    test('generate adds warning for SET NOT NULL', () {
      final content = MigrationFileWriter.generate([
        const AlterColumnNullability('users', 'email', false),
      ]);
      expect(content, contains('-- WARNING:'));
      expect(content, contains('Setting NOT NULL'));
    });

    test('generate does not add warning for DROP NOT NULL', () {
      final content = MigrationFileWriter.generate([
        const AlterColumnNullability('users', 'email', true),
      ]);
      expect(content, isNot(contains('-- WARNING:')));
    });

    test('generate with multiple ops', () {
      final content = MigrationFileWriter.generate([
        const AddColumn(
          'users',
          SchemaColumn(name: 'bio', type: ColumnType('text')),
        ),
        const AlterColumnType('users', 'email', 'varchar(255)'),
        const AlterColumnNullability('users', 'name', false),
        const AlterColumnDefault('users', 'status', "'active'"),
      ]);
      expect(content, contains('ADD COLUMN'));
      expect(content, contains('ALTER COLUMN'));
      expect(content, contains('SET NOT NULL'));
      expect(content, contains('SET DEFAULT'));
      expect(content, contains('-- WARNING:'));
    });

    test('generate with empty ops list', () {
      final content = MigrationFileWriter.generate([]);
      expect(content, contains('BEGIN;'));
      expect(content, contains('COMMIT;'));
    });

    test('generate includes header comment', () {
      final content = MigrationFileWriter.generate([]);
      expect(content, contains('-- Stanza migration'));
      expect(content, contains('-- Generated at'));
    });
  });

  // =========================================================================
  // SchemaTable HELPER EDGE CASES
  // =========================================================================
  group('SchemaTable helpers', () {
    test('columnByName returns null for missing column', () {
      final table = SchemaTable(
        name: 'users',
        columns: [
          const SchemaColumn(name: 'id', type: ColumnType('integer')),
        ],
      );
      expect(table.columnByName('nonexistent'), isNull);
    });

    test('columnByName finds first match', () {
      final table = SchemaTable(
        name: 'users',
        columns: [
          const SchemaColumn(name: 'id', type: ColumnType('integer')),
          const SchemaColumn(name: 'email', type: ColumnType('text')),
          const SchemaColumn(name: 'name', type: ColumnType('text')),
        ],
      );
      expect(table.columnByName('email')?.name, 'email');
      expect(table.columnByName('name')?.name, 'name');
    });

    test('constraint naming conventions', () {
      final table = SchemaTable(name: 'order_items', columns: []);
      expect(table.primaryKeyConstraintName, 'order_items_pkey');
      expect(table.uniqueConstraintName('sku'), 'order_items_sku_key');
      expect(
        table.foreignKeyConstraintName('order_id'),
        'order_items_order_id_fkey',
      );
    });

    test('empty columns list', () {
      final table = SchemaTable(name: 'empty', columns: []);
      expect(table.columnByName('anything'), isNull);
    });
  });

  // =========================================================================
  // UNICODE & SPECIAL CHARACTER HANDLING
  // =========================================================================
  group('unicode and special characters', () {
    test('emoji in string value is parameterized', () {
      final q = SelectQuery(users)
          .where((t) => t.name.equals('John 👍'));
      q.toSql(params);
      expect(params.values['p0'], 'John 👍');
    });

    test('CJK characters in value', () {
      final q = SelectQuery(users)
          .where((t) => t.name.equals('山田太郎'));
      q.toSql(params);
      expect(params.values['p0'], '山田太郎');
    });

    test('Arabic text in value', () {
      final q = SelectQuery(users)
          .where((t) => t.name.equals('محمد'));
      q.toSql(params);
      expect(params.values['p0'], 'محمد');
    });

    test('newlines in string value', () {
      final q = SelectQuery(users)
          .where((t) => t.name.equals('line1\nline2\nline3'));
      q.toSql(params);
      expect(params.values['p0'], 'line1\nline2\nline3');
    });

    test('tab characters in string value', () {
      final q = SelectQuery(users)
          .where((t) => t.name.equals('col1\tcol2'));
      q.toSql(params);
      expect(params.values['p0'], 'col1\tcol2');
    });

    test('mixed unicode in LIKE pattern', () {
      final q = SelectQuery(users)
          .where((t) => t.name.like('%étudiant%'));
      q.toSql(params);
      expect(params.values['p0'], '%étudiant%');
    });

    test('zero-width characters in value', () {
      final q = SelectQuery(users)
          .where((t) => t.name.equals('ab\u200Bcd'));
      q.toSql(params);
      expect(params.values['p0'], 'ab\u200Bcd');
    });

    test('INSERT with unicode values', () {
      final q = InsertQuery(users).values({
        'email': 'ñoño@example.com',
        'name': 'Ñoño González',
      });
      q.toSql(params);
      expect(params.values['p0'], 'ñoño@example.com');
      expect(params.values['p1'], 'Ñoño González');
    });

    test('FTS with unicode query', () {
      final expr = posts.body.fullTextMatches('données optimisation');
      expr.toSql(params);
      expect(params.values['p0'], 'données optimisation');
    });
  });

  // =========================================================================
  // QUERY CHAINING ORDER INDEPENDENCE
  // =========================================================================
  group('chaining order independence', () {
    test('where before join produces same clauses', () {
      final q1 = SelectQuery(posts)
          .where((t) => t.title.like('%dart%'))
          .innerJoin(users, (p, u) => p.authorId.equalsColumn(u.id));
      final q2 = SelectQuery(posts)
          .innerJoin(users, (p, u) => p.authorId.equalsColumn(u.id))
          .where((t) => t.title.like('%dart%'));
      final sql1 = q1.toSql(ParameterCollector());
      final sql2 = q2.toSql(ParameterCollector());
      // Both should produce valid SQL with JOIN before WHERE
      expect(sql1, contains('INNER JOIN users'));
      expect(sql1, contains('WHERE'));
      expect(sql2, contains('INNER JOIN users'));
      expect(sql2, contains('WHERE'));
      // And the SQL should be identical (JOIN always before WHERE in output)
      expect(sql1, sql2);
    });

    test('limit before where produces same SQL', () {
      final q1 = SelectQuery(users)
          .limit(10)
          .where((t) => t.id.greaterThan(0));
      final q2 = SelectQuery(users)
          .where((t) => t.id.greaterThan(0))
          .limit(10);
      final sql1 = q1.toSql(ParameterCollector());
      final sql2 = q2.toSql(ParameterCollector());
      expect(sql1, sql2);
    });

    test('orderBy before where produces same SQL', () {
      final q1 = SelectQuery(users)
          .orderBy((t) => t.name.asc())
          .where((t) => t.id.greaterThan(0));
      final q2 = SelectQuery(users)
          .where((t) => t.id.greaterThan(0))
          .orderBy((t) => t.name.asc());
      final sql1 = q1.toSql(ParameterCollector());
      final sql2 = q2.toSql(ParameterCollector());
      expect(sql1, sql2);
    });

    test('groupBy before selectOnly', () {
      final q = SelectQuery(posts)
          .groupBy((t) => [t.authorId])
          .selectOnly((t) => [t.authorId])
          .selectExpression(posts.id.count().as('cnt'));
      final sql = q.toSql(params);
      expect(sql, contains('SELECT posts.author_id'));
      expect(sql, contains('GROUP BY'));
      expect(sql, contains('COUNT'));
    });
  });

  // =========================================================================
  // CROSS-TABLE OPERATIONS
  // =========================================================================
  group('cross-table operations', () {
    test('ColumnComparison between different tables', () {
      final expr =
          ColumnComparison('posts.author_id', '=', 'users.id');
      expect(expr.toSql(params), 'posts.author_id = users.id');
      expect(params.values, isEmpty);
    });

    test('column equalsColumn preserves qualified names', () {
      final expr = posts.authorId.equalsColumn(users.id);
      expect(expr.toSql(params), 'posts.author_id = users.id');
    });

    test('subquery from different table', () {
      final activeUserIds = SelectQuery(users)
          .selectOnly((t) => [t.id])
          .where((t) => t.email.isNotNull());
      final approvedComments = SelectQuery(comments)
          .selectOnly((t) => [t.postId])
          .where((t) => t.approved.isTrue());
      final q = SelectQuery(posts)
          .where((t) => t.authorId.isInQuery(activeUserIds))
          .where((t) => t.id.isInQuery(approvedComments));
      final sql = q.toSql(params);
      expect(sql, contains('IN (SELECT users.id'));
      expect(sql, contains('IN (SELECT comments.post_id'));
    });
  });

  // =========================================================================
  // AGGREGATE EXPRESSION COMPOSITION
  // =========================================================================
  group('aggregate expression composition', () {
    test('HAVING with OR of aggregates', () {
      final q = SelectQuery(posts)
          .selectOnly((t) => [t.authorId])
          .groupBy((t) => [t.authorId])
          .having(
            (t) =>
                t.id.count().equals(1) |
                t.id.count().greaterThan(100),
          );
      final sql = q.toSql(params);
      expect(sql, contains('OR'));
      expect(sql, contains('COUNT(posts.id) = @p0'));
      expect(sql, contains('COUNT(posts.id) > @p1'));
    });

    test('HAVING with NOT of aggregate', () {
      final q = SelectQuery(posts)
          .selectOnly((t) => [t.authorId])
          .groupBy((t) => [t.authorId])
          .having((t) => Not(t.id.count().equals(0)));
      final sql = q.toSql(params);
      expect(sql, contains('NOT (COUNT(posts.id) = @p0)'));
    });

    test('CountAll in HAVING', () {
      final q = SelectQuery(posts)
          .selectOnly((t) => [t.authorId])
          .selectExpression(const CountAll(alias: 'total'))
          .groupBy((t) => [t.authorId])
          .having((t) => const CountAll().greaterThan(5));
      final sql = q.toSql(params);
      expect(sql, contains('HAVING COUNT(*) > @p0'));
    });

    test('multiple aggregates on different columns', () {
      final q = SelectQuery(comments)
          .selectOnly((t) => [t.postId])
          .selectExpression(comments.id.count().as('comment_count'))
          .selectExpression(comments.score.avg().as('avg_score'))
          .selectExpression(comments.score.sum().as('total_score'))
          .selectExpression(comments.createdAt.max().as('latest'))
          .groupBy((t) => [t.postId])
          .having(
            (t) =>
                t.id.count().greaterThan(0) &
                t.score.avg().greaterThan(3.0),
          );
      final sql = q.toSql(params);
      expect(sql, contains('COUNT(comments.id) AS comment_count'));
      expect(sql, contains('AVG(comments.score) AS avg_score'));
      expect(sql, contains('SUM(comments.score) AS total_score'));
      expect(sql, contains('MAX(comments.created_at) AS latest'));
      expect(sql, contains('HAVING'));
    });
  });

  // =========================================================================
  // SQLITE PARAMETER PREFIX
  // =========================================================================
  group('SQLite parameter prefix', () {
    test('all query types work with : prefix', () {
      final sqliteParams = ParameterCollector(placeholderPrefix: ':');

      // SELECT
      final select = SelectQuery(users)
          .where((t) => t.id.equals(1));
      expect(select.toSql(sqliteParams), contains(':p0'));

      // INSERT
      final insertParams = ParameterCollector(placeholderPrefix: ':');
      final insert = InsertQuery(users)
          .values({'email': 'a@b.com', 'name': 'Test'});
      final insertSql = insert.toSql(insertParams);
      expect(insertSql, contains(':p0'));
      expect(insertSql, contains(':p1'));

      // UPDATE
      final updateParams = ParameterCollector(placeholderPrefix: ':');
      final update = UpdateQuery(users, {'name': 'X'})
          .where((t) => t.id.equals(1));
      final updateSql = update.toSql(updateParams);
      expect(updateSql, contains(':p0'));
      expect(updateSql, contains(':p1'));

      // DELETE
      final deleteParams = ParameterCollector(placeholderPrefix: ':');
      final delete = DeleteQuery(users)
          .where((t) => t.id.equals(1));
      expect(delete.toSql(deleteParams), contains(':p0'));
    });

    test('expressions use correct prefix', () {
      final sqliteParams = ParameterCollector(placeholderPrefix: ':');
      final expr = Comparison('x', '=', 1) & Between('y', 10, 20);
      final sql = expr.toSql(sqliteParams);
      expect(sql, contains(':p0'));
      expect(sql, contains(':p1'));
      expect(sql, contains(':p2'));
      expect(sql, isNot(contains('@')));
    });
  });

  // =========================================================================
  // EDGE CASE: TABLE DESCRIPTOR PROPERTIES
  // =========================================================================
  group('TableDescriptor properties', () {
    test('tableName is correct', () {
      expect(users.tableName, 'users');
      expect(posts.tableName, 'posts');
      expect(comments.tableName, 'comments');
    });

    test('columns list has correct length', () {
      expect(users.columns, hasLength(4));
      expect(posts.columns, hasLength(5));
      expect(comments.columns, hasLength(7));
    });

    test('primaryKey is correct column', () {
      expect(users.primaryKey.name, 'id');
      expect(posts.primaryKey.name, 'id');
      expect(comments.primaryKey.name, 'id');
    });

    test('column qualified names are correct', () {
      expect(users.id.qualified, 'users.id');
      expect(users.email.qualified, 'users.email');
      expect(posts.authorId.qualified, 'posts.author_id');
      expect(comments.score.qualified, 'comments.score');
    });

    test('fromRow maps correctly', () {
      final now = DateTime.now();
      final user = users.fromRow({
        'id': 1,
        'email': 'test@test.com',
        'name': 'Test',
        'created_at': now,
      });
      expect(user.id, 1);
      expect(user.email, 'test@test.com');
      expect(user.name, 'Test');
      expect(user.createdAt, now);
    });
  });

  // =========================================================================
  // FLUENT API CONTRACTS
  // =========================================================================
  group('fluent API returns same instance', () {
    test('SelectQuery methods return same query for chaining', () {
      final q = SelectQuery(users);
      expect(q.where((t) => t.id.equals(1)), same(q));
      expect(q.orderBy((t) => t.name.asc()), same(q));
      expect(q.limit(10), same(q));
      expect(q.offset(5), same(q));
      expect(q.distinct(), same(q));
      expect(q.selectOnly((t) => [t.id]), same(q));
      expect(q.selectExpression(users.id.count()), same(q));
      expect(q.groupBy((t) => [t.id]), same(q));
      expect(q.having((t) => users.id.count().greaterThan(0)), same(q));
    });

    test('InsertQuery methods return same query for chaining', () {
      final q = InsertQuery(users);
      expect(q.values({'email': 'a', 'name': 'b'}), same(q));
      expect(q.returning(), same(q));
      expect(
        q.onConflictDoNothing(target: [users.email]),
        same(q),
      );
    });

    test('UpdateQuery methods return same query for chaining', () {
      final q = UpdateQuery(users, {'name': 'X'});
      expect(q.where((t) => t.id.equals(1)), same(q));
      expect(q.returning(), same(q));
      expect(q.allowUnsafe(), same(q));
    });

    test('DeleteQuery methods return same query for chaining', () {
      final q = DeleteQuery(users);
      expect(q.where((t) => t.id.equals(1)), same(q));
      expect(q.returning(), same(q));
      expect(q.allowUnsafe(), same(q));
    });
  });
}
