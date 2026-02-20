import 'package:stanza/stanza.dart';
import 'package:test/test.dart';

void main() {
  late ParameterCollector params;

  setUp(() {
    params = ParameterCollector();
  });

  group('Comparison', () {
    test('renders column = @param', () {
      final expr = Comparison('users.email', '=', 'foo@bar.com');
      expect(expr.toSql(params), 'users.email = @p0');
      expect(params.values, {'p0': 'foo@bar.com'});
    });

    test('renders column > @param', () {
      final expr = Comparison('users.age', '>', 21);
      expect(expr.toSql(params), 'users.age > @p0');
      expect(params.values, {'p0': 21});
    });
  });

  group('And', () {
    test('renders (left AND right)', () {
      final left = Comparison('users.name', '=', 'Kirk');
      final right = Comparison('users.age', '>', 30);
      final expr = And(left, right);
      expect(
        expr.toSql(params),
        '(users.name = @p0 AND users.age > @p1)',
      );
      expect(params.values, {'p0': 'Kirk', 'p1': 30});
    });

    test('& operator creates And', () {
      final left = Comparison('a', '=', 1);
      final right = Comparison('b', '=', 2);
      final expr = left & right;
      expect(expr, isA<And>());
      expect(expr.toSql(params), '(a = @p0 AND b = @p1)');
    });
  });

  group('Or', () {
    test('renders (left OR right)', () {
      final left = Comparison('users.role', '=', 'admin');
      final right = Comparison('users.role', '=', 'superadmin');
      final expr = Or(left, right);
      expect(
        expr.toSql(params),
        '(users.role = @p0 OR users.role = @p1)',
      );
    });

    test('| operator creates Or', () {
      final left = Comparison('a', '=', 1);
      final right = Comparison('b', '=', 2);
      final expr = left | right;
      expect(expr, isA<Or>());
      expect(expr.toSql(params), '(a = @p0 OR b = @p1)');
    });
  });

  group('compound expressions', () {
    test('(a AND b) OR c', () {
      final a = Comparison('x', '=', 1);
      final b = Comparison('y', '=', 2);
      final c = Comparison('z', '=', 3);
      final expr = (a & b) | c;
      expect(
        expr.toSql(params),
        '((x = @p0 AND y = @p1) OR z = @p2)',
      );
    });

    test('a AND (b OR c)', () {
      final a = Comparison('x', '=', 1);
      final b = Comparison('y', '=', 2);
      final c = Comparison('z', '=', 3);
      final expr = a & (b | c);
      expect(
        expr.toSql(params),
        '(x = @p0 AND (y = @p1 OR z = @p2))',
      );
    });
  });

  group('Not', () {
    test('renders NOT (inner)', () {
      final inner = Comparison('users.active', '=', true);
      final expr = Not(inner);
      expect(expr.toSql(params), 'NOT (users.active = @p0)');
    });
  });

  group('InList', () {
    test('renders column IN (@p0, @p1, @p2)', () {
      final expr = InList('users.role', ['admin', 'editor', 'viewer']);
      expect(expr.toSql(params), 'users.role IN (@p0, @p1, @p2)');
      expect(params.values, {'p0': 'admin', 'p1': 'editor', 'p2': 'viewer'});
    });
  });

  group('NotInList', () {
    test('renders column NOT IN (@p0, @p1)', () {
      final expr = NotInList('users.status', ['banned', 'deleted']);
      expect(expr.toSql(params), 'users.status NOT IN (@p0, @p1)');
    });
  });

  group('IsNull / IsNotNull', () {
    test('renders column IS NULL', () {
      final expr = IsNull('users.deleted_at');
      expect(expr.toSql(params), 'users.deleted_at IS NULL');
      expect(params.values, isEmpty);
    });

    test('renders column IS NOT NULL', () {
      final expr = IsNotNull('users.email');
      expect(expr.toSql(params), 'users.email IS NOT NULL');
      expect(params.values, isEmpty);
    });
  });

  group('Between', () {
    test('renders column BETWEEN @low AND @high', () {
      final expr = Between('users.age', 18, 65);
      expect(expr.toSql(params), 'users.age BETWEEN @p0 AND @p1');
      expect(params.values, {'p0': 18, 'p1': 65});
    });
  });

  group('Like', () {
    test('renders case-sensitive LIKE', () {
      final expr = Like('users.name', '%Kirk%', caseSensitive: true);
      expect(expr.toSql(params), 'users.name LIKE @p0');
      expect(params.values, {'p0': '%Kirk%'});
    });

    test('renders case-insensitive ILIKE', () {
      final expr = Like('users.name', '%kirk%', caseSensitive: false);
      expect(expr.toSql(params), 'users.name ILIKE @p0');
    });
  });

  group('Raw', () {
    test('renders raw SQL without params', () {
      final expr = Raw('users.age > 0');
      expect(expr.toSql(params), 'users.age > 0');
      expect(params.values, isEmpty);
    });

    test('renders raw SQL with named params', () {
      final expr = Raw(
        'users.name = :name AND users.age > :age',
        paramValues: {'name': 'Kirk', 'age': 30},
      );
      final sql = expr.toSql(params);
      expect(sql, 'users.name = @p0 AND users.age > @p1');
      expect(params.values, {'p0': 'Kirk', 'p1': 30});
    });
  });

  group('ParameterCollector', () {
    test('assigns incrementing parameter names', () {
      final p0 = params.add('first');
      final p1 = params.add('second');
      final p2 = params.add(42);
      expect(p0, '@p0');
      expect(p1, '@p1');
      expect(p2, '@p2');
      expect(params.values, {'p0': 'first', 'p1': 'second', 'p2': 42});
      expect(params.length, 3);
    });

    test('handles null values', () {
      final p = params.add(null);
      expect(p, '@p0');
      expect(params.values, {'p0': null});
    });
  });
}
