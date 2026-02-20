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

  group('basic DELETE', () {
    test('delete with where', () {
      final q = DeleteQuery(users).where((t) => t.id.equals(1));
      expect(
        q.toSql(params),
        'DELETE FROM users WHERE users.id = @p0',
      );
      expect(params.values, {'p0': 1});
    });

    test('delete with compound where', () {
      final q = DeleteQuery(users).where(
        (t) => t.email.like('%@spam.com') | t.name.isNull(),
      );
      expect(
        q.toSql(params),
        'DELETE FROM users WHERE (users.email LIKE @p0 OR users.name IS NULL)',
      );
    });

    test('delete with multiple where calls', () {
      final q = DeleteQuery(users)
          .where((t) => t.id.greaterThan(100))
          .where((t) => t.email.like('%@test.com'));
      expect(
        q.toSql(params),
        'DELETE FROM users WHERE (users.id > @p0 AND users.email LIKE @p1)',
      );
    });
  });

  group('safety', () {
    test('throws without where clause', () {
      final q = DeleteQuery(users);
      expect(() => q.toSql(params), throwsStateError);
    });

    test('allowUnsafe bypasses where requirement', () {
      final q = DeleteQuery(users).allowUnsafe();
      expect(q.toSql(params), 'DELETE FROM users');
    });
  });

  group('RETURNING', () {
    test('delete with returning', () {
      final q = DeleteQuery(users)
          .where((t) => t.id.equals(1))
          .returning();
      expect(
        q.toSql(params),
        'DELETE FROM users WHERE users.id = @p0 RETURNING *',
      );
    });
  });

  group('build()', () {
    test('returns sql and parameters', () {
      final q = DeleteQuery(users).where((t) => t.id.equals(99));
      final result = q.build();
      expect(result.sql, 'DELETE FROM users WHERE users.id = @p0');
      expect(result.parameters, {'p0': 99});
    });
  });
}
