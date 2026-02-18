import 'package:test/test.dart';
import 'package:stanza/stanza.dart';
import 'test_helpers.dart';

void main() {
  late AnimalTable t;

  setUp(() {
    t = AnimalTable();
  });

  /// Helper to build a select query with a single where operation.
  SelectQuery selectWith(void Function(SelectQuery q) build) {
    final q = SelectQuery(t)..selectStar();
    build(q);
    return q;
  }

  group('WhereOperation - null checks', () {
    test('isNull', () {
      final q = selectWith((q) => q.where(t.color).isNull());
      expect(q.statement(), contains('WHERE mammal.color IS NULL'));
      expect(q.substitutionValues, isEmpty);
    });

    test('isNotNull', () {
      final q = selectWith((q) => q.where(t.color).isNotNull());
      expect(q.statement(), contains('WHERE mammal.color IS NOT NULL'));
      expect(q.substitutionValues, isEmpty);
    });
  });

  group('WhereOperation - numeric comparisons', () {
    test('isEqualTo', () {
      final q = selectWith((q) => q.where(t.legs).isEqualTo(4));
      expect(q.statement(),
          contains('WHERE mammal.number_of_legs = @mammal_number_of_legs_0'));
      expect(q.substitutionValues['mammal_number_of_legs_0'], 4);
    });

    test('isGreaterThan', () {
      final q = selectWith((q) => q.where(t.legs).isGreaterThan(2));
      expect(q.statement(), contains('mammal.number_of_legs > @'));
      expect(q.substitutionValues.values.first, 2);
    });

    test('isGreaterThanOrEqualTo', () {
      final q =
          selectWith((q) => q.where(t.legs).isGreaterThanOrEqualTo(4));
      expect(q.statement(), contains('mammal.number_of_legs >= @'));
      expect(q.substitutionValues.values.first, 4);
    });

    test('isLessThan', () {
      final q = selectWith((q) => q.where(t.legs).isLessThan(6));
      expect(q.statement(), contains('mammal.number_of_legs < @'));
      expect(q.substitutionValues.values.first, 6);
    });

    test('isLessThanOrEqualTo', () {
      final q = selectWith((q) => q.where(t.legs).isLessThanOrEqualTo(4));
      expect(q.statement(), contains('mammal.number_of_legs <= @'));
      expect(q.substitutionValues.values.first, 4);
    });
  });

  group('WhereOperation - string matching', () {
    test('matches case-insensitive (default)', () {
      final q = selectWith((q) => q.where(t.name).matches('Tiger'));
      expect(q.statement(), contains('LOWER(mammal.name)'));
      expect(q.statement(), contains('= @'));
      expect(q.substitutionValues.values.first, 'tiger');
    });

    test('matches case-sensitive', () {
      final q = selectWith(
          (q) => q.where(t.name).matches('Tiger', caseSensitive: true));
      expect(q.statement(), isNot(contains('LOWER')));
      expect(q.substitutionValues.values.first, 'Tiger');
    });

    test('startsWith case-insensitive', () {
      final q = selectWith((q) => q.where(t.name).startsWith('tig'));
      expect(q.statement(), contains('LOWER(mammal.name)'));
      expect(q.statement(), contains('LIKE'));
      // Value should end with %
      final value = q.substitutionValues.values.first as String;
      expect(value, endsWith('%'));
      expect(value, startsWith('tig'));
    });

    test('endsWith case-insensitive', () {
      final q = selectWith((q) => q.where(t.name).endsWith('er'));
      expect(q.statement(), contains('LIKE'));
      final value = q.substitutionValues.values.first as String;
      expect(value, startsWith('%'));
      expect(value, endsWith('er'));
    });

    test('contains case-insensitive', () {
      final q = selectWith((q) => q.where(t.name).contains('ige'));
      expect(q.statement(), contains('LIKE'));
      final value = q.substitutionValues.values.first as String;
      expect(value, startsWith('%'));
      expect(value, endsWith('%'));
      expect(value, contains('ige'));
    });

    test('startsWith case-sensitive', () {
      final q = selectWith(
          (q) => q.where(t.name).startsWith('Tig', caseSensitive: true));
      expect(q.statement(), isNot(contains('LOWER')));
      final value = q.substitutionValues.values.first as String;
      expect(value, 'Tig%');
    });
  });

  group('WhereOperation - LIKE escaping', () {
    test('escapes percent in startsWith', () {
      final q = selectWith((q) => q.where(t.name).startsWith('100%'));
      final value = q.substitutionValues.values.first as String;
      expect(value, r'100\%%');
    });

    test('escapes underscore in contains', () {
      final q = selectWith((q) => q.where(t.name).contains('a_b'));
      final value = q.substitutionValues.values.first as String;
      expect(value, contains(r'a\_b'));
    });

    test('escapes backslash in endsWith', () {
      final q = selectWith((q) => q.where(t.name).endsWith(r'path\to'));
      final value = q.substitutionValues.values.first as String;
      expect(value, contains(r'path\\to'));
    });
  });

  group('WhereOperation - boolean', () {
    test('isTrue', () {
      final q = selectWith((q) => q.where(t.color).isTrue());
      expect(q.statement(), contains('mammal.color = true'));
      expect(q.substitutionValues, isEmpty);
    });

    test('isFalse', () {
      final q = selectWith((q) => q.where(t.color).isFalse());
      expect(q.statement(), contains('mammal.color = false'));
      expect(q.substitutionValues, isEmpty);
    });
  });

  group('WhereOperation - date comparisons', () {
    final date = DateTime(2024, 6, 15);

    test('dateIsBefore', () {
      final q = selectWith((q) => q.where(t.color).dateIsBefore(date));
      expect(q.statement(), contains('mammal.color::date <'));
      expect(q.substitutionValues.values.first, date);
    });

    test('dateIsAfter', () {
      final q = selectWith((q) => q.where(t.color).dateIsAfter(date));
      expect(q.statement(), contains('mammal.color::date >'));
      expect(q.substitutionValues.values.first, date);
    });

    test('dateIsOn', () {
      final q = selectWith((q) => q.where(t.color).dateIsOn(date));
      expect(q.statement(), contains('mammal.color::date ='));
      expect(q.substitutionValues.values.first, date);
    });
  });

  group('WhereOperation - raw', () {
    test('raw condition', () {
      final q =
          selectWith((q) => q.where(t.id).raw("mammal.id = ANY('{1,2,3}')"));
      expect(q.statement(), contains("mammal.id = ANY('{1,2,3}')"));
    });
  });

  group('WhereClause - combinators', () {
    test('where AND', () {
      final q = SelectQuery(t)
        ..selectStar()
        ..where(t.legs).isEqualTo(4)
        ..and(t.color).matches('brown');
      final stmt = q.statement();
      expect(stmt, contains('WHERE'));
      expect(stmt, contains('AND'));
    });

    test('where OR', () {
      final q = SelectQuery(t)
        ..selectStar()
        ..where(t.legs).isEqualTo(4)
        ..or(t.legs).isEqualTo(2);
      expect(q.statement(), contains('OR'));
    });

    test('where with brackets', () {
      final q = SelectQuery(t)
        ..selectStar()
        ..where(t.color).matches('brown')
        ..and(t.legs, openBracket: true).isEqualTo(4)
        ..or(t.legs, closeBracket: true).isEqualTo(2);
      final stmt = q.statement();
      expect(stmt, contains('('));
      expect(stmt, contains(')'));
    });
  });

  group('WhereOperation - SQL injection safety', () {
    test('string values are parameterized not interpolated', () {
      final q = selectWith(
          (q) => q.where(t.name).matches("'; DROP TABLE mammal; --"));
      final stmt = q.statement();
      expect(stmt, isNot(contains('DROP TABLE')));
      expect(q.substitutionValues.values.first,
          "'; drop table mammal; --");
    });

    test('numeric values are parameterized', () {
      final q = selectWith((q) => q.where(t.legs).isEqualTo(4));
      final stmt = q.statement();
      // The value should be in substitutionValues, referenced by token in SQL
      expect(stmt, matches(RegExp(r'@mammal_number_of_legs_\d+')));
      expect(q.substitutionValues.values, contains(4));
    });
  });
}
