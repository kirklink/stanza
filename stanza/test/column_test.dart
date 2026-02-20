import 'package:stanza/stanza.dart';
import 'package:test/test.dart';

void main() {
  late ParameterCollector params;

  setUp(() {
    params = ParameterCollector();
  });

  group('Column (universal operations)', () {
    final col = IntColumn('id', 'users');

    test('qualified name', () {
      expect(col.qualified, 'users.id');
    });

    test('equals', () {
      final expr = col.equals(42);
      expect(expr.toSql(params), 'users.id = @p0');
      expect(params.values, {'p0': 42});
    });

    test('notEquals', () {
      final expr = col.notEquals(0);
      expect(expr.toSql(params), 'users.id != @p0');
    });

    test('isNull', () {
      final expr = col.isNull();
      expect(expr.toSql(params), 'users.id IS NULL');
    });

    test('isNotNull', () {
      final expr = col.isNotNull();
      expect(expr.toSql(params), 'users.id IS NOT NULL');
    });

    test('isIn', () {
      final expr = col.isIn([1, 2, 3]);
      expect(expr.toSql(params), 'users.id IN (@p0, @p1, @p2)');
      expect(params.values, {'p0': 1, 'p1': 2, 'p2': 3});
    });

    test('notIn', () {
      final expr = col.notIn([4, 5]);
      expect(expr.toSql(params), 'users.id NOT IN (@p0, @p1)');
    });
  });

  group('Column (ordering)', () {
    final col = StringColumn('name', 'users');

    test('asc', () {
      expect(col.asc().toSql(), 'users.name ASC');
    });

    test('desc', () {
      expect(col.desc().toSql(), 'users.name DESC');
    });
  });

  group('IntColumn', () {
    final col = IntColumn('age', 'users');

    test('greaterThan', () {
      final expr = col.greaterThan(21);
      expect(expr.toSql(params), 'users.age > @p0');
      expect(params.values, {'p0': 21});
    });

    test('greaterThanOrEqual', () {
      final expr = col.greaterThanOrEqual(18);
      expect(expr.toSql(params), 'users.age >= @p0');
    });

    test('lessThan', () {
      final expr = col.lessThan(65);
      expect(expr.toSql(params), 'users.age < @p0');
    });

    test('lessThanOrEqual', () {
      final expr = col.lessThanOrEqual(100);
      expect(expr.toSql(params), 'users.age <= @p0');
    });

    test('between', () {
      final expr = col.between(18, 65);
      expect(expr.toSql(params), 'users.age BETWEEN @p0 AND @p1');
      expect(params.values, {'p0': 18, 'p1': 65});
    });
  });

  group('DoubleColumn', () {
    final col = DoubleColumn('score', 'results');

    test('greaterThan', () {
      final expr = col.greaterThan(9.5);
      expect(expr.toSql(params), 'results.score > @p0');
      expect(params.values, {'p0': 9.5});
    });

    test('between', () {
      final expr = col.between(0.0, 100.0);
      expect(expr.toSql(params), 'results.score BETWEEN @p0 AND @p1');
    });
  });

  group('StringColumn', () {
    final col = StringColumn('email', 'users');

    test('like (case-sensitive)', () {
      final expr = col.like('%@example.com');
      expect(expr.toSql(params), 'users.email LIKE @p0');
      expect(params.values, {'p0': '%@example.com'});
    });

    test('ilike (case-insensitive)', () {
      final expr = col.ilike('%@EXAMPLE.COM');
      expect(expr.toSql(params), 'users.email ILIKE @p0');
    });

    test('startsWith', () {
      final expr = col.startsWith('admin');
      expect(expr.toSql(params), 'users.email LIKE @p0');
      expect(params.values, {'p0': 'admin%'});
    });

    test('endsWith', () {
      final expr = col.endsWith('.com');
      expect(expr.toSql(params), 'users.email LIKE @p0');
      expect(params.values, {'p0': '%.com'});
    });

    test('contains', () {
      final expr = col.contains('example');
      expect(expr.toSql(params), 'users.email LIKE @p0');
      expect(params.values, {'p0': '%example%'});
    });
  });

  group('BoolColumn', () {
    final col = BoolColumn('active', 'users');

    test('isTrue', () {
      final expr = col.isTrue();
      expect(expr.toSql(params), 'users.active = @p0');
      expect(params.values, {'p0': true});
    });

    test('isFalse', () {
      final expr = col.isFalse();
      expect(expr.toSql(params), 'users.active = @p0');
      expect(params.values, {'p0': false});
    });
  });

  group('DateTimeColumn', () {
    final col = DateTimeColumn('created_at', 'users');
    final now = DateTime(2025, 1, 15, 12, 0, 0);
    final later = DateTime(2025, 12, 31, 23, 59, 59);

    test('before', () {
      final expr = col.before(now);
      expect(expr.toSql(params), 'users.created_at < @p0');
      expect(params.values, {'p0': now});
    });

    test('after', () {
      final expr = col.after(now);
      expect(expr.toSql(params), 'users.created_at > @p0');
    });

    test('onOrBefore', () {
      final expr = col.onOrBefore(now);
      expect(expr.toSql(params), 'users.created_at <= @p0');
    });

    test('onOrAfter', () {
      final expr = col.onOrAfter(now);
      expect(expr.toSql(params), 'users.created_at >= @p0');
    });

    test('between', () {
      final expr = col.between(now, later);
      expect(expr.toSql(params), 'users.created_at BETWEEN @p0 AND @p1');
      expect(params.values, {'p0': now, 'p1': later});
    });
  });

  group('composing column expressions', () {
    test('two columns with & produce AND', () {
      final email = StringColumn('email', 'users');
      final active = BoolColumn('active', 'users');
      final expr = email.equals('test@test.com') & active.isTrue();
      expect(
        expr.toSql(params),
        '(users.email = @p0 AND users.active = @p1)',
      );
    });

    test('two columns with | produce OR', () {
      final role = StringColumn('role', 'users');
      final expr = role.equals('admin') | role.equals('superadmin');
      expect(
        expr.toSql(params),
        '(users.role = @p0 OR users.role = @p1)',
      );
    });

    test('mixed & and | with grouping', () {
      final name = StringColumn('name', 'users');
      final age = IntColumn('age', 'users');
      final active = BoolColumn('active', 'users');

      // (name = 'Kirk' AND age > 30) OR active = true
      final expr =
          (name.equals('Kirk') & age.greaterThan(30)) | active.isTrue();
      expect(
        expr.toSql(params),
        '((users.name = @p0 AND users.age > @p1) OR users.active = @p2)',
      );
    });
  });
}
