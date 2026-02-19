import 'package:test/test.dart';
import 'package:stanza/stanza.dart';
import 'test_helpers.dart';

void main() {
  late AnimalTable t;

  setUp(() {
    t = AnimalTable();
  });

  group('InsertQuery RETURNING', () {
    test('returningStar appends RETURNING *', () {
      final q = InsertQuery(t);
      q.insert(t.name, 'Tiger');
      q.returningStar();
      final stmt = q.statement();
      expect(stmt, contains('RETURNING *'));
    });

    test('returning specific fields', () {
      final q = InsertQuery(t);
      q.insert(t.name, 'Tiger');
      q.returning([t.id, t.name]);
      final stmt = q.statement();
      expect(stmt, contains('RETURNING mammal.id, mammal.name'));
    });

    test('without returning produces no RETURNING clause', () {
      final q = InsertQuery(t);
      q.insert(t.name, 'Tiger');
      final stmt = q.statement();
      expect(stmt, isNot(contains('RETURNING')));
    });

    test('returningStar with insertEntity', () {
      final animal = Animal()
        ..name = 'Tiger'
        ..legs = 4
        ..color = 'orange';
      final q = InsertQuery(t)
        ..insertEntity(animal)
        ..returningStar();
      final stmt = q.statement();
      expect(stmt, startsWith('INSERT INTO mammal'));
      expect(stmt, endsWith('RETURNING *'));
    });

    test('fork preserves returning', () {
      final q = InsertQuery(t);
      q.insert(t.name, 'Tiger');
      q.returningStar();
      final forked = q.fork();
      expect(forked.statement(), contains('RETURNING *'));
    });

    test('fork is independent for returning', () {
      final q = InsertQuery(t);
      q.insert(t.name, 'Tiger');
      final forked = q.fork();
      forked.returningStar();
      expect(forked.statement(), contains('RETURNING *'));
      expect(q.statement(), isNot(contains('RETURNING')));
    });
  });

  group('UpdateQuery RETURNING', () {
    test('returningStar appends RETURNING *', () {
      final q = UpdateQuery(t)
        ..column(t.color).string('white')
        ..where(t.id).isEqualTo(1)
        ..returningStar();
      final stmt = q.statement();
      expect(stmt, contains('SET'));
      expect(stmt, contains('WHERE'));
      expect(stmt, endsWith('RETURNING *'));
    });

    test('returning specific fields', () {
      final q = UpdateQuery(t)
        ..column(t.color).string('white')
        ..where(t.id).isEqualTo(1)
        ..returning([t.id, t.color]);
      final stmt = q.statement();
      expect(stmt, contains('RETURNING mammal.id, mammal.color'));
    });

    test('RETURNING comes after WHERE', () {
      final q = UpdateQuery(t)
        ..column(t.color).string('white')
        ..where(t.id).isEqualTo(1)
        ..returningStar();
      final stmt = q.statement();
      final whereIdx = stmt.indexOf('WHERE');
      final retIdx = stmt.indexOf('RETURNING');
      expect(whereIdx, lessThan(retIdx));
    });

    test('fork preserves returning', () {
      final q = UpdateQuery(t)
        ..column(t.color).string('white')
        ..where(t.id).isEqualTo(1)
        ..returningStar();
      final forked = q.fork();
      expect(forked.statement(), contains('RETURNING *'));
    });
  });

  group('DeleteQuery RETURNING', () {
    test('returningStar appends RETURNING *', () {
      final q = DeleteQuery(t)
        ..where(t.id).isEqualTo(1)
        ..returningStar();
      final stmt = q.statement();
      expect(stmt, contains('DELETE FROM mammal'));
      expect(stmt, contains('WHERE'));
      expect(stmt, endsWith('RETURNING *'));
    });

    test('returning specific fields', () {
      final q = DeleteQuery(t)
        ..where(t.id).isEqualTo(1)
        ..returning([t.id]);
      final stmt = q.statement();
      expect(stmt, contains('RETURNING mammal.id'));
    });

    test('RETURNING comes after WHERE', () {
      final q = DeleteQuery(t)
        ..where(t.id).isEqualTo(1)
        ..returningStar();
      final stmt = q.statement();
      final whereIdx = stmt.indexOf('WHERE');
      final retIdx = stmt.indexOf('RETURNING');
      expect(whereIdx, lessThan(retIdx));
    });

    test('RETURNING without WHERE', () {
      final q = DeleteQuery(t)..returningStar();
      final stmt = q.statement();
      expect(stmt, contains('DELETE FROM mammal'));
      expect(stmt, contains('RETURNING *'));
      expect(stmt, isNot(contains('WHERE')));
    });

    test('fork preserves returning', () {
      final q = DeleteQuery(t)
        ..where(t.id).isEqualTo(1)
        ..returningStar();
      final forked = q.fork();
      expect(forked.statement(), contains('RETURNING *'));
    });
  });

  group('pretty print', () {
    test('RETURNING on separate line in pretty mode', () {
      final q = InsertQuery(t);
      q.insert(t.name, 'Tiger');
      q.returningStar();
      final stmt = q.statement(pretty: true);
      expect(stmt, contains('\nRETURNING *'));
    });

    test('update with all clauses pretty printed', () {
      final q = UpdateQuery(t)
        ..column(t.color).string('white')
        ..where(t.id).isEqualTo(1)
        ..returningStar();
      final stmt = q.statement(pretty: true);
      expect(stmt, contains('\nSET'));
      expect(stmt, contains('\nWHERE'));
      expect(stmt, contains('\nRETURNING *'));
    });
  });
}
