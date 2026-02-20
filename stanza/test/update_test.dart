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

  group('basic UPDATE', () {
    test('update single column with where', () {
      final q = UpdateQuery(users, UserUpdate(name: 'New Name').toRow())
          .where((t) => t.id.equals(1));
      expect(
        q.toSql(params),
        'UPDATE users SET name = @p0 WHERE users.id = @p1',
      );
      expect(params.values, {'p0': 'New Name', 'p1': 1});
    });

    test('update multiple columns', () {
      final q = UpdateQuery(
        users,
        UserUpdate(email: 'new@test.com', name: 'New').toRow(),
      ).where((t) => t.id.equals(1));
      final sql = q.toSql(params);
      expect(sql, contains('SET email = @p0, name = @p1'));
      expect(sql, contains('WHERE users.id = @p2'));
    });

    test('update with compound where', () {
      final q = UpdateQuery(users, UserUpdate(name: 'X').toRow()).where(
        (t) => t.email.like('%@old.com') & t.createdAt.isNotNull(),
      );
      final sql = q.toSql(params);
      expect(sql, contains('WHERE (users.email LIKE @p1 AND users.created_at IS NOT NULL)'));
    });
  });

  group('safety', () {
    test('throws without where clause', () {
      final q = UpdateQuery(users, UserUpdate(name: 'X').toRow());
      expect(() => q.toSql(params), throwsStateError);
    });

    test('allowUnsafe bypasses where requirement', () {
      final q = UpdateQuery(users, UserUpdate(name: 'X').toRow()).allowUnsafe();
      expect(q.toSql(params), 'UPDATE users SET name = @p0');
    });

    test('throws on empty values', () {
      final q = UpdateQuery(users, <String, dynamic>{})
          .where((t) => t.id.equals(1));
      expect(() => q.toSql(params), throwsStateError);
    });
  });

  group('RETURNING', () {
    test('update with returning', () {
      final q = UpdateQuery(users, UserUpdate(name: 'New').toRow())
          .where((t) => t.id.equals(1))
          .returning();
      expect(q.toSql(params), endsWith('RETURNING *'));
    });
  });

  group('build()', () {
    test('returns sql and parameters', () {
      final q = UpdateQuery(users, UserUpdate(name: 'Kirk').toRow())
          .where((t) => t.id.equals(42));
      final result = q.build();
      expect(result.sql, 'UPDATE users SET name = @p0 WHERE users.id = @p1');
      expect(result.parameters, {'p0': 'Kirk', 'p1': 42});
    });
  });
}
