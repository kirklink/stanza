import 'package:test/test.dart';
import 'package:stanza/stanza.dart';
import 'test_helpers.dart';

void main() {
  late AnimalTable t;
  late OwnerTable owner;
  late HabitatTable habitat;

  setUp(() {
    t = AnimalTable();
    owner = OwnerTable();
    habitat = HabitatTable();
  });

  group('JoinClause', () {
    group('INNER JOIN', () {
      test('basic inner join', () {
        final q = SelectQuery(t)
          ..selectStar()
          ..innerJoin(owner).on(t.ownerId, owner.id);
        final stmt = q.statement();
        expect(stmt, contains('INNER JOIN owner ON mammal.owner_id = owner.id'));
      });

      test('inner join with select from joined table', () {
        final q = SelectQuery(t)
          ..selectStar()
          ..selectFields([owner.name..rename('owner_name')])
          ..innerJoin(owner).on(t.ownerId, owner.id);
        final stmt = q.statement();
        expect(stmt, contains('mammal.*'));
        expect(stmt, contains('owner.name AS owner_name'));
        expect(stmt, contains('INNER JOIN owner'));
      });

      test('inner join with where on primary table', () {
        final q = SelectQuery(t)
          ..selectStar()
          ..innerJoin(owner).on(t.ownerId, owner.id)
          ..where(t.legs).isGreaterThan(2);
        final stmt = q.statement();
        expect(stmt, contains('INNER JOIN owner ON mammal.owner_id = owner.id'));
        expect(stmt, contains('WHERE mammal.number_of_legs >'));
      });

      test('inner join with where on joined table', () {
        final q = SelectQuery(t)
          ..selectStar()
          ..innerJoin(owner).on(t.ownerId, owner.id)
          ..where(owner.name).matches('alice');
        final stmt = q.statement();
        expect(stmt, contains('INNER JOIN owner'));
        expect(stmt, contains('WHERE LOWER(owner.name)'));
        expect(q.substitutionValues.values.first, 'alice');
      });
    });

    group('LEFT JOIN', () {
      test('basic left join', () {
        final q = SelectQuery(t)
          ..selectStar()
          ..leftJoin(owner).on(t.ownerId, owner.id);
        final stmt = q.statement();
        expect(stmt, contains('LEFT JOIN owner ON mammal.owner_id = owner.id'));
      });

      test('left join with null check on joined table', () {
        final q = SelectQuery(t)
          ..selectStar()
          ..leftJoin(owner).on(t.ownerId, owner.id)
          ..where(owner.id).isNull();
        final stmt = q.statement();
        expect(stmt, contains('LEFT JOIN owner'));
        expect(stmt, contains('WHERE owner.id IS NULL'));
      });
    });

    group('RIGHT JOIN', () {
      test('basic right join', () {
        final q = SelectQuery(t)
          ..selectStar()
          ..rightJoin(owner).on(t.ownerId, owner.id);
        final stmt = q.statement();
        expect(stmt, contains('RIGHT JOIN owner ON mammal.owner_id = owner.id'));
      });
    });

    group('CROSS JOIN', () {
      test('basic cross join (no ON clause)', () {
        final q = SelectQuery(t)
          ..selectStar()
          ..crossJoin(owner);
        final stmt = q.statement();
        expect(stmt, contains('CROSS JOIN owner'));
        expect(stmt, isNot(contains('ON')));
      });
    });

    group('multiple joins', () {
      test('two inner joins', () {
        final q = SelectQuery(t)
          ..selectStar()
          ..innerJoin(owner).on(t.ownerId, owner.id)
          ..innerJoin(habitat).on(t.habitatId, habitat.id);
        final stmt = q.statement();
        expect(stmt, contains('INNER JOIN owner ON mammal.owner_id = owner.id'));
        expect(
            stmt, contains('INNER JOIN habitat ON mammal.habitat_id = habitat.id'));
      });

      test('mixed join types', () {
        final q = SelectQuery(t)
          ..selectStar()
          ..innerJoin(owner).on(t.ownerId, owner.id)
          ..leftJoin(habitat).on(t.habitatId, habitat.id);
        final stmt = q.statement();
        expect(stmt, contains('INNER JOIN owner'));
        expect(stmt, contains('LEFT JOIN habitat'));
      });

      test('multiple joins with where and order by', () {
        final q = SelectQuery(t)
          ..selectStar()
          ..selectFields([owner.name..rename('owner_name')])
          ..innerJoin(owner).on(t.ownerId, owner.id)
          ..leftJoin(habitat).on(t.habitatId, habitat.id)
          ..where(owner.name).matches('alice')
          ..orderBy(t.name)
          ..limit(10);
        final stmt = q.statement();
        expect(stmt, contains('INNER JOIN owner'));
        expect(stmt, contains('LEFT JOIN habitat'));
        expect(stmt, contains('WHERE LOWER(owner.name)'));
        expect(stmt, contains('ORDER BY mammal.name ASC'));
        expect(stmt, contains('LIMIT 10'));
      });
    });

    group('statement ordering', () {
      test('joins appear between FROM and WHERE', () {
        final q = SelectQuery(t)
          ..selectStar()
          ..innerJoin(owner).on(t.ownerId, owner.id)
          ..where(t.legs).isEqualTo(4);
        final stmt = q.statement();
        final fromIdx = stmt.indexOf('FROM mammal');
        final joinIdx = stmt.indexOf('INNER JOIN owner');
        final whereIdx = stmt.indexOf('WHERE');
        expect(fromIdx, lessThan(joinIdx));
        expect(joinIdx, lessThan(whereIdx));
      });

      test('joins appear before GROUP BY', () {
        final q = SelectQuery(t)
          ..selectFields([t.color, t.id..count()..rename('count')])
          ..innerJoin(owner).on(t.ownerId, owner.id)
          ..groupBy([t.color]);
        final stmt = q.statement();
        final joinIdx = stmt.indexOf('INNER JOIN');
        final groupIdx = stmt.indexOf('GROUP BY');
        expect(joinIdx, lessThan(groupIdx));
      });

      test('full query with join preserves clause order', () {
        final q = SelectQuery(t)
          ..selectStar()
          ..innerJoin(owner).on(t.ownerId, owner.id)
          ..where(t.legs).isGreaterThan(0)
          ..orderBy(t.name)
          ..limit(10)
          ..offset(5);
        final stmt = q.statement();
        final selectIdx = stmt.indexOf('SELECT');
        final fromIdx = stmt.indexOf('FROM');
        final joinIdx = stmt.indexOf('INNER JOIN');
        final whereIdx = stmt.indexOf('WHERE');
        final orderIdx = stmt.indexOf('ORDER BY');
        final limitIdx = stmt.indexOf('LIMIT');
        final offsetIdx = stmt.indexOf('OFFSET');
        expect(selectIdx, lessThan(fromIdx));
        expect(fromIdx, lessThan(joinIdx));
        expect(joinIdx, lessThan(whereIdx));
        expect(whereIdx, lessThan(orderIdx));
        expect(orderIdx, lessThan(limitIdx));
        expect(limitIdx, lessThan(offsetIdx));
      });
    });

    group('fork', () {
      test('fork preserves joins', () {
        final q = SelectQuery(t)
          ..selectStar()
          ..innerJoin(owner).on(t.ownerId, owner.id)
          ..where(owner.name).matches('alice');
        final forked = q.fork();
        expect(forked.statement(), q.statement());
      });

      test('fork is independent — adding join to fork does not affect original',
          () {
        final q = SelectQuery(t)
          ..selectStar()
          ..innerJoin(owner).on(t.ownerId, owner.id);
        final forked = q.fork();
        forked.leftJoin(habitat).on(t.habitatId, habitat.id);
        expect(forked.statement(), contains('LEFT JOIN habitat'));
        expect(q.statement(), isNot(contains('LEFT JOIN habitat')));
      });
    });

    group('pretty print', () {
      test('pretty print puts joins on separate lines', () {
        final q = SelectQuery(t)
          ..selectStar()
          ..innerJoin(owner).on(t.ownerId, owner.id)
          ..where(t.legs).isEqualTo(4);
        final stmt = q.statement(pretty: true);
        expect(stmt, contains('\nINNER JOIN owner'));
        expect(stmt, contains('\nWHERE'));
      });
    });
  });

  group('BelongsTo join helpers', () {
    test('innerJoinOwner generates correct SQL with aliased fields', () {
      final q = SelectQuery(t)..selectStar();
      t.innerJoinOwner(q);
      final stmt = q.statement();
      expect(stmt, contains('mammal.*'));
      expect(stmt, contains('owner.id AS owner__id'));
      expect(stmt, contains('owner.name AS owner__name'));
      expect(stmt,
          contains('INNER JOIN owner ON mammal.owner_id = owner.id'));
    });

    test('leftJoinOwner generates correct SQL', () {
      final q = SelectQuery(t)..selectStar();
      t.leftJoinOwner(q);
      final stmt = q.statement();
      expect(stmt,
          contains('LEFT JOIN owner ON mammal.owner_id = owner.id'));
      expect(stmt, contains('owner.id AS owner__id'));
    });

    test('join helper works with where on joined table', () {
      final q = SelectQuery(t)..selectStar();
      t.innerJoinOwner(q);
      q.where(owner.name).matches('alice');
      final stmt = q.statement();
      expect(stmt, contains('INNER JOIN owner'));
      expect(stmt, contains('WHERE LOWER(owner.name)'));
      expect(q.substitutionValues.values.first, 'alice');
    });

    test('join helper works with where and order by', () {
      final q = SelectQuery(t)..selectStar();
      t.innerJoinOwner(q);
      q
        ..where(t.legs).isGreaterThan(2)
        ..orderBy(t.name)
        ..limit(10);
      final stmt = q.statement();
      expect(stmt, contains('INNER JOIN owner'));
      expect(stmt, contains('WHERE mammal.number_of_legs >'));
      expect(stmt, contains('ORDER BY mammal.name ASC'));
      expect(stmt, contains('LIMIT 10'));
    });

    test('ownerFromRow extracts typed Owner from aliased columns', () {
      final row = <String, dynamic>{
        'id': 1,
        'name': 'Tiger',
        'number_of_legs': 4,
        'color': 'orange',
        'owner_id': 10,
        'owner__id': 10,
        'owner__name': 'Alice',
      };
      final result = t.ownerFromRow(row);
      expect(result, isNotNull);
      expect(result!.id, 10);
      expect(result.name, 'Alice');
    });

    test('ownerFromRow returns null for LEFT JOIN miss', () {
      final row = <String, dynamic>{
        'id': 1,
        'name': 'Tiger',
        'number_of_legs': 4,
        'color': 'orange',
        'owner_id': null,
        'owner__id': null,
        'owner__name': null,
      };
      final result = t.ownerFromRow(row);
      expect(result, isNull);
    });

    test('statement ordering with join helper', () {
      final q = SelectQuery(t)..selectStar();
      t.innerJoinOwner(q);
      q
        ..where(t.legs).isEqualTo(4)
        ..limit(5);
      final stmt = q.statement();
      final fromIdx = stmt.indexOf('FROM mammal');
      final joinIdx = stmt.indexOf('INNER JOIN');
      final whereIdx = stmt.indexOf('WHERE');
      final limitIdx = stmt.indexOf('LIMIT');
      expect(fromIdx, lessThan(joinIdx));
      expect(joinIdx, lessThan(whereIdx));
      expect(whereIdx, lessThan(limitIdx));
    });
  });
}
