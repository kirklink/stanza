import 'package:test/test.dart';
import 'package:stanza/stanza.dart';
import 'test_helpers.dart';

void main() {
  late AnimalTable t;

  setUp(() {
    t = AnimalTable();
  });

  group('DeleteQuery', () {
    test('delete with where', () {
      final q = DeleteQuery(t)..where(t.id).isEqualTo(1);
      final stmt = q.statement();
      expect(stmt, startsWith('DELETE FROM mammal'));
      expect(stmt, contains('WHERE mammal.id ='));
      expect(q.substitutionValues['mammal_id_0'], 1);
    });

    test('delete with multiple conditions', () {
      final q = DeleteQuery(t)
        ..where(t.color).matches('brown')
        ..and(t.legs).isLessThan(4);
      final stmt = q.statement();
      expect(stmt, contains('WHERE'));
      expect(stmt, contains('AND'));
    });

    test('delete without where produces statement', () {
      final q = DeleteQuery(t);
      final stmt = q.statement();
      expect(stmt, startsWith('DELETE FROM mammal'));
    });

    test('fork preserves where clauses', () {
      final q = DeleteQuery(t)..where(t.id).isEqualTo(1);
      final forked = q.fork();
      expect(forked.statement(), q.statement());
    });

    test('fork is independent', () {
      final q = DeleteQuery(t)..where(t.color).matches('brown');
      final forked = q.fork();
      forked.and(t.legs).isEqualTo(4);
      expect(forked.statement(), contains('AND'));
      expect(q.statement(), isNot(contains('AND')));
    });
  });
}
