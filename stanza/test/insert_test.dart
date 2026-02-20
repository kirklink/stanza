import 'package:stanza/stanza.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  late $UserTable users;
  late ParameterCollector params;

  setUp(() {
    users = $UserTable();
    params = ParameterCollector();
  });

  group('basic INSERT', () {
    test('single row', () {
      final q = InsertQuery(users).values(
        UserInsert(email: 'foo@bar.com', name: 'Kirk').toRow(),
      );
      expect(
        q.toSql(params),
        'INSERT INTO users (email, name) VALUES (@p0, @p1)',
      );
      expect(params.values, {'p0': 'foo@bar.com', 'p1': 'Kirk'});
    });

    test('single row with optional field', () {
      final now = DateTime(2025, 1, 1);
      final q = InsertQuery(users).values(
        UserInsert(email: 'foo@bar.com', name: 'Kirk', createdAt: now).toRow(),
      );
      expect(
        q.toSql(params),
        'INSERT INTO users (email, name, created_at) VALUES (@p0, @p1, @p2)',
      );
      expect(params.values, {'p0': 'foo@bar.com', 'p1': 'Kirk', 'p2': now});
    });

    test('batch insert', () {
      final q = InsertQuery(users).valuesList([
        UserInsert(email: 'a@b.com', name: 'Alice').toRow(),
        UserInsert(email: 'c@d.com', name: 'Bob').toRow(),
      ]);
      expect(
        q.toSql(params),
        'INSERT INTO users (email, name) VALUES (@p0, @p1), (@p2, @p3)',
      );
      expect(params.values, {
        'p0': 'a@b.com',
        'p1': 'Alice',
        'p2': 'c@d.com',
        'p3': 'Bob',
      });
    });

    test('throws on empty values', () {
      final q = InsertQuery(users);
      expect(() => q.toSql(params), throwsStateError);
    });
  });

  group('RETURNING', () {
    test('insert with returning', () {
      final q = InsertQuery(users)
          .values(UserInsert(email: 'foo@bar.com', name: 'Kirk').toRow())
          .returning();
      expect(q.toSql(params), endsWith('RETURNING *'));
    });
  });

  group('ON CONFLICT', () {
    test('do nothing', () {
      final q = InsertQuery(users)
          .values(UserInsert(email: 'foo@bar.com', name: 'Kirk').toRow())
          .onConflictDoNothing(target: [users.email]);
      final sql = q.toSql(params);
      expect(sql, contains('ON CONFLICT (email) DO NOTHING'));
    });

    test('do update (upsert)', () {
      final q = InsertQuery(users)
          .values(UserInsert(email: 'foo@bar.com', name: 'Kirk').toRow())
          .onConflict(
            target: [users.email],
            doUpdate: UserUpdate(name: 'Kirk Updated').toRow(),
          )
          .returning();
      final sql = q.toSql(params);
      expect(sql, contains('ON CONFLICT (email) DO UPDATE SET name = @p2'));
      expect(sql, endsWith('RETURNING *'));
    });
  });

  group('build()', () {
    test('returns sql and parameters', () {
      final q = InsertQuery(users)
          .values(UserInsert(email: 'test@test.com', name: 'Test').toRow())
          .returning();
      final result = q.build();
      expect(result.sql, contains('INSERT INTO users'));
      expect(result.sql, contains('RETURNING *'));
      expect(result.parameters, {'p0': 'test@test.com', 'p1': 'Test'});
    });
  });
}
