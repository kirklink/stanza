/// Integration tests against a real PostgreSQL database (e.g. Neon).
///
/// These tests require the DATABASE_URL environment variable to be set.
/// Run with: DATABASE_URL=postgresql://... dart test test/integration_test.dart
///
/// Tables are created/dropped automatically per test run.
@TestOn('vm')
library;

import 'dart:io';
import 'package:test/test.dart';
import 'package:stanza/stanza.dart';

// ---------------------------------------------------------------------------
// Entity + Table definitions (mirrors what the code generator produces)
// ---------------------------------------------------------------------------

class Owner {
  int id = 0;
  String name = '';

  static final $table = _OwnerTable();
}

class _OwnerTable extends Table<Owner> {
  @override
  final String $name = 'test_owner';

  @override
  final Type $type = Owner;

  Field get id => Field('test_owner', 'id');
  Field get name => Field('test_owner', 'name');

  @override
  Owner fromDb(Map<String, dynamic> map) {
    return Owner()
      ..id = map['id'] as int
      ..name = map['name'] as String;
  }

  @override
  Map<String, dynamic> toDb(Owner instance) {
    return <String, dynamic>{
      'name': instance.name,
    };
  }
}

class Animal {
  int id = 0;
  String name = '';
  int legs = 0;
  String color = '';
  int? ownerId;

  static final $table = _AnimalTable();
}

class _AnimalTable extends Table<Animal> {
  @override
  final String $name = 'test_animal';

  @override
  final Type $type = Animal;

  Field get id => Field('test_animal', 'id');
  Field get name => Field('test_animal', 'name');
  Field get legs => Field('test_animal', 'number_of_legs');
  Field get color => Field('test_animal', 'color');
  Field get ownerId => Field('test_animal', 'owner_id');

  @override
  Animal fromDb(Map<String, dynamic> map) {
    return Animal()
      ..id = map['id'] as int
      ..name = map['name'] as String
      ..legs = map['number_of_legs'] as int
      ..color = map['color'] as String
      ..ownerId = map['owner_id'] as int?;
  }

  @override
  Map<String, dynamic> toDb(Animal instance) {
    return <String, dynamic>{
      'name': instance.name,
      'number_of_legs': instance.legs,
      'color': instance.color,
      'owner_id': instance.ownerId,
    };
  }

  // --- BelongsTo: Owner via ownerId (mimics generated code) ---

  List<Field> get _ownerJoinFields => [
        Field('test_owner', 'id')..rename('owner__id'),
        Field('test_owner', 'name')..rename('owner__name'),
      ];

  void innerJoinOwner(SelectQuery q) {
    q.selectFields(_ownerJoinFields);
    q.innerJoin(Owner.$table).on(ownerId, Field('test_owner', 'id'));
  }

  void leftJoinOwner(SelectQuery q) {
    q.selectFields(_ownerJoinFields);
    q.leftJoin(Owner.$table).on(ownerId, Field('test_owner', 'id'));
  }

  Owner? ownerFromRow(Map<String, dynamic> row) {
    if (row['owner__id'] == null) return null;
    return Owner()
      ..id = row['owner__id'] as int
      ..name = row['owner__name'] as String;
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  final databaseUrl = Platform.environment['DATABASE_URL'];

  if (databaseUrl == null || databaseUrl.isEmpty) {
    // Skip all tests gracefully when no DATABASE_URL is set.
    test('integration tests skipped (no DATABASE_URL)', () {});
    return;
  }

  late Stanza stanza;
  final t = Animal.$table;
  final owner = Owner.$table;

  setUpAll(() async {
    stanza = Stanza.url(databaseUrl);

    // Create tables (drop first to ensure clean state)
    await stanza.rawExecute(
        'DROP TABLE IF EXISTS test_animal CASCADE');
    await stanza.rawExecute(
        'DROP TABLE IF EXISTS test_owner CASCADE');

    await stanza.rawExecute('''
      CREATE TABLE test_owner (
        id SERIAL PRIMARY KEY,
        name TEXT NOT NULL
      )
    ''');

    await stanza.rawExecute('''
      CREATE TABLE test_animal (
        id SERIAL PRIMARY KEY,
        name TEXT NOT NULL UNIQUE,
        number_of_legs INT NOT NULL,
        color TEXT NOT NULL,
        owner_id INT REFERENCES test_owner(id)
      )
    ''');

    // Seed data
    await stanza.rawExecute(
      "INSERT INTO test_owner (name) VALUES (@name)",
      parameters: {'name': 'Alice'},
    );
    await stanza.rawExecute(
      "INSERT INTO test_owner (name) VALUES (@name)",
      parameters: {'name': 'Bob'},
    );

    await stanza.rawExecute(
      "INSERT INTO test_animal (name, number_of_legs, color, owner_id) "
      "VALUES (@name, @legs, @color, @oid)",
      parameters: {'name': 'Tiger', 'legs': 4, 'color': 'orange', 'oid': 1},
    );
    await stanza.rawExecute(
      "INSERT INTO test_animal (name, number_of_legs, color, owner_id) "
      "VALUES (@name, @legs, @color, @oid)",
      parameters: {'name': 'Eagle', 'legs': 2, 'color': 'brown', 'oid': 2},
    );
    await stanza.rawExecute(
      "INSERT INTO test_animal (name, number_of_legs, color, owner_id) "
      "VALUES (@name, @legs, @color, @oid)",
      parameters: {'name': 'Snake', 'legs': 0, 'color': 'green', 'oid': 1},
    );
    // One animal with no owner (for LEFT JOIN test)
    await stanza.rawExecute(
      "INSERT INTO test_animal (name, number_of_legs, color) "
      "VALUES (@name, @legs, @color)",
      parameters: {'name': 'Jellyfish', 'legs': 0, 'color': 'transparent'},
    );
  });

  tearDownAll(() async {
    await stanza.rawExecute('DROP TABLE IF EXISTS test_animal CASCADE');
    await stanza.rawExecute('DROP TABLE IF EXISTS test_owner CASCADE');
    await stanza.close();
  });

  group('SELECT', () {
    test('select all animals', () async {
      final q = SelectQuery(t)..selectStar();
      final result = await stanza.execute<Animal>(q);
      expect(result.length, 4);
      expect(result.entities.map((a) => a.name),
          containsAll(['Tiger', 'Eagle', 'Snake', 'Jellyfish']));
    });

    test('select with where equals', () async {
      final q = SelectQuery(t)
        ..selectStar()
        ..where(t.name).matches('Tiger', caseSensitive: true);
      final result = await stanza.execute<Animal>(q);
      expect(result.length, 1);
      expect(result.first!.value!.name, 'Tiger');
      expect(result.first!.value!.legs, 4);
      expect(result.first!.value!.color, 'orange');
    });

    test('select with where greater than', () async {
      final q = SelectQuery(t)
        ..selectStar()
        ..where(t.legs).isGreaterThan(0)
        ..orderBy(t.legs);
      final result = await stanza.execute<Animal>(q);
      expect(result.length, 2);
      expect(result.entities[0].name, 'Eagle'); // 2 legs
      expect(result.entities[1].name, 'Tiger'); // 4 legs
    });

    test('select with limit and offset', () async {
      final q = SelectQuery(t)
        ..selectStar()
        ..orderBy(t.name)
        ..limit(2)
        ..offset(1);
      final result = await stanza.execute<Animal>(q);
      expect(result.length, 2);
      // Alphabetical: Eagle, Jellyfish, Snake, Tiger → offset 1 = Jellyfish, Snake
      expect(result.entities[0].name, 'Jellyfish');
      expect(result.entities[1].name, 'Snake');
    });

    test('select with order by descending', () async {
      final q = SelectQuery(t)
        ..selectStar()
        ..orderBy(t.name, descending: true);
      final result = await stanza.execute<Animal>(q);
      expect(result.entities.first.name, 'Tiger');
      expect(result.entities.last.name, 'Eagle');
    });

    test('select with count aggregate', () async {
      final q = SelectQuery(t)
        ..selectFields([t.color, t.id..count()..rename('count')])
        ..groupBy([t.color])
        ..orderBy(t.color);
      final result = await stanza.execute<Animal>(q);
      expect(result.isNotEmpty, isTrue);
      for (final row in result.all) {
        expect(row.aggregate.containsKey('count'), isTrue);
      }
    });
  });

  group('INSERT', () {
    test('insert and retrieve entity', () async {
      final insert = InsertQuery(t);
      final newAnimal = Animal()
        ..name = 'Penguin'
        ..legs = 2
        ..color = 'black'
        ..ownerId = 2;
      insert.insertEntity(newAnimal);
      await stanza.execute(insert);

      final q = SelectQuery(t)
        ..selectStar()
        ..where(t.name).matches('Penguin', caseSensitive: true);
      final result = await stanza.execute<Animal>(q);
      expect(result.length, 1);
      expect(result.first!.value!.color, 'black');
      expect(result.first!.value!.ownerId, 2);

      // Clean up
      final del = DeleteQuery(t)..where(t.name).matches('Penguin', caseSensitive: true);
      await stanza.execute(del);
    });

    test('batch insert multiple entities', () async {
      final animals = [
        Animal()..name = 'Parrot'..legs = 2..color = 'red'..ownerId = 1,
        Animal()..name = 'Octopus'..legs = 8..color = 'purple'..ownerId = 2,
        Animal()..name = 'Ant'..legs = 6..color = 'black'..ownerId = 1,
      ];
      final q = InsertQuery(t)..insertEntities<Animal>(animals);
      await stanza.execute(q);

      final check = SelectQuery(t)
        ..selectStar()
        ..where(t.name).isIn(['Parrot', 'Octopus', 'Ant']);
      final result = await stanza.execute<Animal>(check);
      expect(result.length, 3);

      // Clean up
      final del = DeleteQuery(t)
        ..where(t.name).isIn(['Parrot', 'Octopus', 'Ant']);
      await stanza.execute(del);
    });

    test('batch insert with RETURNING', () async {
      final animals = [
        Animal()..name = 'Frog'..legs = 4..color = 'green'..ownerId = 1,
        Animal()..name = 'Crab'..legs = 10..color = 'red'..ownerId = 2,
      ];
      final q = InsertQuery(t)
        ..insertEntities<Animal>(animals)
        ..returningStar();
      final result = await stanza.execute<Animal>(q);
      expect(result.length, 2);
      final names = result.entities.map((a) => a.name).toSet();
      expect(names, containsAll(['Frog', 'Crab']));

      // Clean up
      final del = DeleteQuery(t)
        ..where(t.name).isIn(['Frog', 'Crab']);
      await stanza.execute(del);
    });
  });

  group('ON CONFLICT (upsert)', () {
    test('DO NOTHING skips duplicate', () async {
      // Tiger already exists from seed data
      final q = InsertQuery(t)
        ..insert(t.name, 'Tiger')
        ..insert(t.legs, 100)
        ..insert(t.color, 'blue')
        ..onConflictDoNothing(target: [t.name]);
      await stanza.execute(q);

      // Verify Tiger is unchanged
      final check = SelectQuery(t)
        ..selectStar()
        ..where(t.name).matches('Tiger', caseSensitive: true);
      final result = await stanza.execute<Animal>(check);
      expect(result.length, 1);
      expect(result.first!.value!.legs, 4); // unchanged
      expect(result.first!.value!.color, 'orange'); // unchanged
    });

    test('DO UPDATE SET updates on conflict', () async {
      // Tiger already exists from seed data
      final q = InsertQuery(t)
        ..insert(t.name, 'Tiger')
        ..insert(t.legs, 4)
        ..insert(t.color, 'white')
        ..onConflict(
          target: [t.name],
          doUpdate: (set) => set..column(t.color).string('white-striped'),
        );
      await stanza.execute(q);

      // Verify Tiger's color was updated
      final check = SelectQuery(t)
        ..selectStar()
        ..where(t.name).matches('Tiger', caseSensitive: true);
      final result = await stanza.execute<Animal>(check);
      expect(result.length, 1);
      expect(result.first!.value!.color, 'white-striped');

      // Restore original color
      final restore = UpdateQuery(t)
        ..column(t.color).string('orange')
        ..where(t.name).matches('Tiger', caseSensitive: true);
      await stanza.execute(restore);
    });

    test('DO UPDATE with RETURNING', () async {
      final q = InsertQuery(t)
        ..insert(t.name, 'Tiger')
        ..insert(t.legs, 4)
        ..insert(t.color, 'silver')
        ..onConflict(
          target: [t.name],
          doUpdate: (set) => set..column(t.color).string('silver'),
        )
        ..returningStar();
      final result = await stanza.execute<Animal>(q);
      expect(result.length, 1);
      expect(result.first!.value!.name, 'Tiger');
      expect(result.first!.value!.color, 'silver');

      // Restore
      final restore = UpdateQuery(t)
        ..column(t.color).string('orange')
        ..where(t.name).matches('Tiger', caseSensitive: true);
      await stanza.execute(restore);
    });

    test('DO NOTHING inserts new row when no conflict', () async {
      final q = InsertQuery(t)
        ..insert(t.name, 'Dolphin')
        ..insert(t.legs, 0)
        ..insert(t.color, 'grey')
        ..onConflictDoNothing(target: [t.name]);
      await stanza.execute(q);

      final check = SelectQuery(t)
        ..selectStar()
        ..where(t.name).matches('Dolphin', caseSensitive: true);
      final result = await stanza.execute<Animal>(check);
      expect(result.length, 1);

      // Clean up
      final del = DeleteQuery(t)
        ..where(t.name).matches('Dolphin', caseSensitive: true);
      await stanza.execute(del);
    });
  });

  group('UPDATE', () {
    test('update a field and verify', () async {
      final update = UpdateQuery(t)
        ..column(t.color).string('white')
        ..where(t.name).matches('Tiger', caseSensitive: true);
      await stanza.execute(update);

      final q = SelectQuery(t)
        ..selectStar()
        ..where(t.name).matches('Tiger', caseSensitive: true);
      final result = await stanza.execute<Animal>(q);
      expect(result.first!.value!.color, 'white');

      // Restore original
      final restore = UpdateQuery(t)
        ..column(t.color).string('orange')
        ..where(t.name).matches('Tiger', caseSensitive: true);
      await stanza.execute(restore);
    });
  });

  group('DELETE', () {
    test('delete and verify removal', () async {
      final insert = InsertQuery(t);
      final temp = Animal()
        ..name = 'TempBug'
        ..legs = 6
        ..color = 'red';
      insert.insertEntity(temp);
      await stanza.execute(insert);

      // Verify it exists
      final check = SelectQuery(t)
        ..selectStar()
        ..where(t.name).matches('TempBug', caseSensitive: true);
      var result = await stanza.execute<Animal>(check);
      expect(result.length, 1);

      // Delete it
      final del = DeleteQuery(t)..where(t.name).matches('TempBug', caseSensitive: true);
      await stanza.execute(del);

      // Verify gone
      result = await stanza.execute<Animal>(check);
      expect(result.length, 0);
    });
  });

  group('JOIN', () {
    test('inner join returns animals with owners', () async {
      final q = SelectQuery(t)..selectStar();
      t.innerJoinOwner(q);
      q.orderBy(t.name);
      final result = await stanza.execute<Animal>(q);

      // Jellyfish has no owner, so INNER JOIN excludes it
      expect(result.length, 3);
      final names = result.entities.map((a) => a.name).toList();
      expect(names, containsAll(['Tiger', 'Eagle', 'Snake']));
      expect(names, isNot(contains('Jellyfish')));

      // Verify ownerFromRow extracts typed Owner
      for (final row in result.all) {
        final o = t.ownerFromRow(row.aggregate);
        expect(o, isNotNull);
        expect(o!.name, isIn(['Alice', 'Bob']));
      }
    });

    test('left join includes animals without owners', () async {
      final q = SelectQuery(t)..selectStar();
      t.leftJoinOwner(q);
      q.orderBy(t.name);
      final result = await stanza.execute<Animal>(q);

      // LEFT JOIN includes all animals
      expect(result.length, 4);

      // Jellyfish should have null owner
      final jellyfishRow =
          result.all.firstWhere((r) => r.value!.name == 'Jellyfish');
      final jellyOwner = t.ownerFromRow(jellyfishRow.aggregate);
      expect(jellyOwner, isNull);

      // Tiger should have Alice
      final tigerRow =
          result.all.firstWhere((r) => r.value!.name == 'Tiger');
      final tigerOwner = t.ownerFromRow(tigerRow.aggregate);
      expect(tigerOwner, isNotNull);
      expect(tigerOwner!.name, 'Alice');
    });

    test('inner join with where on joined table', () async {
      final q = SelectQuery(t)..selectStar();
      t.innerJoinOwner(q);
      q.where(owner.name).matches('Alice', caseSensitive: true);
      q.orderBy(t.name);
      final result = await stanza.execute<Animal>(q);

      // Alice owns Tiger and Snake
      expect(result.length, 2);
      expect(result.entities.map((a) => a.name),
          containsAll(['Tiger', 'Snake']));
    });

    test('inner join with where and limit', () async {
      final q = SelectQuery(t)..selectStar();
      t.innerJoinOwner(q);
      q
        ..where(t.legs).isGreaterThan(0)
        ..orderBy(t.legs)
        ..limit(1);
      final result = await stanza.execute<Animal>(q);

      expect(result.length, 1);
      expect(result.first!.value!.name, 'Eagle'); // 2 legs, owned by Bob
      final o = t.ownerFromRow(result.first!.aggregate);
      expect(o!.name, 'Bob');
    });
  });

  group('transaction', () {
    test('transaction rolls back on error', () async {
      final beforeQ = SelectQuery(t)..selectStar();
      final before = await stanza.execute<Animal>(beforeQ);
      final countBefore = before.length;

      try {
        await stanza.runTransaction((session) async {
          final insert = InsertQuery(t);
          final temp = Animal()
            ..name = 'Rollback'
            ..legs = 8
            ..color = 'purple';
          insert.insertEntity(temp);
          await session.execute(insert);

          // Force an error to trigger rollback
          throw Exception('intentional rollback');
        });
      } catch (_) {
        // Expected
      }

      // Count should be unchanged
      final afterQ = SelectQuery(t)..selectStar();
      final after = await stanza.execute<Animal>(afterQ);
      expect(after.length, countBefore);
    });

    test('transaction commits on success', () async {
      await stanza.runTransaction((session) async {
        final insert = InsertQuery(t);
        final temp = Animal()
          ..name = 'Committed'
          ..legs = 4
          ..color = 'gray';
        insert.insertEntity(temp);
        await session.execute(insert);
      });

      final q = SelectQuery(t)
        ..selectStar()
        ..where(t.name).matches('Committed', caseSensitive: true);
      final result = await stanza.execute<Animal>(q);
      expect(result.length, 1);
      expect(result.first!.value!.color, 'gray');

      // Clean up
      final del = DeleteQuery(t)..where(t.name).matches('Committed', caseSensitive: true);
      await stanza.execute(del);
    });
  });

  group('RETURNING', () {
    test('insert with returningStar returns the inserted row', () async {
      final insert = InsertQuery(t);
      final newAnimal = Animal()
        ..name = 'Parrot'
        ..legs = 2
        ..color = 'green'
        ..ownerId = 1;
      insert.insertEntity(newAnimal);
      insert.returningStar();
      final result = await stanza.execute<Animal>(insert);

      expect(result.length, 1);
      final animal = result.first!.value!;
      expect(animal.name, 'Parrot');
      expect(animal.legs, 2);
      expect(animal.color, 'green');
      expect(animal.id, greaterThan(0)); // auto-generated

      // Clean up
      final del = DeleteQuery(t)..where(t.id).isEqualTo(animal.id);
      await stanza.execute(del);
    });

    test('insert with returning specific fields', () async {
      final insert = InsertQuery(t);
      final newAnimal = Animal()
        ..name = 'Owl'
        ..legs = 2
        ..color = 'brown'
        ..ownerId = 2;
      insert.insertEntity(newAnimal);
      insert.returning([t.id, t.name]);
      final result = await stanza.execute<Animal>(insert);

      expect(result.length, 1);
      // Only id and name are returned; fromDb will fail on missing columns
      // but aggregate map should have them
      final row = result.first!.aggregate;
      expect(row['id'], greaterThan(0));
      expect(row['name'], 'Owl');

      // Clean up
      final del = DeleteQuery(t)..where(t.id).isEqualTo(row['id'] as int);
      await stanza.execute(del);
    });

    test('update with returningStar returns the updated row', () async {
      final update = UpdateQuery(t)
        ..column(t.color).string('silver')
        ..where(t.name).matches('Tiger', caseSensitive: true)
        ..returningStar();
      final result = await stanza.execute<Animal>(update);

      expect(result.length, 1);
      final animal = result.first!.value!;
      expect(animal.name, 'Tiger');
      expect(animal.color, 'silver');

      // Restore
      final restore = UpdateQuery(t)
        ..column(t.color).string('orange')
        ..where(t.name).matches('Tiger', caseSensitive: true);
      await stanza.execute(restore);
    });

    test('delete with returningStar returns the deleted row', () async {
      // Insert a temp row
      final insert = InsertQuery(t);
      final temp = Animal()
        ..name = 'Dodo'
        ..legs = 2
        ..color = 'gray';
      insert.insertEntity(temp);
      insert.returningStar();
      final insertResult = await stanza.execute<Animal>(insert);
      final dodoId = insertResult.first!.value!.id;

      // Delete with RETURNING
      final del = DeleteQuery(t)
        ..where(t.id).isEqualTo(dodoId)
        ..returningStar();
      final result = await stanza.execute<Animal>(del);

      expect(result.length, 1);
      expect(result.first!.value!.name, 'Dodo');
      expect(result.first!.value!.id, dodoId);

      // Verify it's gone
      final check = SelectQuery(t)
        ..selectStar()
        ..where(t.id).isEqualTo(dodoId);
      final gone = await stanza.execute<Animal>(check);
      expect(gone.length, 0);
    });
  });

  group('IN / NOT IN / BETWEEN', () {
    test('isIn returns matching rows', () async {
      final q = SelectQuery(t)
        ..selectStar()
        ..where(t.color).isIn(['orange', 'green']);
      final result = await stanza.execute<Animal>(q);
      expect(result.length, 2);
      final names = result.entities.map((a) => a.name).toSet();
      expect(names, containsAll(['Tiger', 'Snake']));
    });

    test('isNotIn excludes matching rows', () async {
      final q = SelectQuery(t)
        ..selectStar()
        ..where(t.color).isNotIn(['orange', 'green']);
      final result = await stanza.execute<Animal>(q);
      expect(result.length, 2);
      final names = result.entities.map((a) => a.name).toSet();
      expect(names, containsAll(['Eagle', 'Jellyfish']));
    });

    test('isIn with numeric values', () async {
      final q = SelectQuery(t)
        ..selectStar()
        ..where(t.legs).isIn([0, 2]);
      final result = await stanza.execute<Animal>(q);
      expect(result.length, 3);
      final names = result.entities.map((a) => a.name).toSet();
      expect(names, containsAll(['Eagle', 'Snake', 'Jellyfish']));
    });

    test('isBetween returns rows in range (inclusive)', () async {
      final q = SelectQuery(t)
        ..selectStar()
        ..where(t.legs).isBetween(1, 4);
      final result = await stanza.execute<Animal>(q);
      expect(result.length, 2);
      final names = result.entities.map((a) => a.name).toSet();
      expect(names, containsAll(['Tiger', 'Eagle']));
    });

    test('isBetween excludes out-of-range rows', () async {
      final q = SelectQuery(t)
        ..selectStar()
        ..where(t.legs).isBetween(5, 100);
      final result = await stanza.execute<Animal>(q);
      expect(result.length, 0);
    });
  });

  group('DISTINCT', () {
    test('distinct returns unique values', () async {
      // legs has duplicates: 0 (Snake, Jellyfish), 2 (Eagle), 4 (Tiger)
      final q = SelectQuery(t)
        ..distinct()
        ..selectFields([t.legs])
        ..orderBy(t.legs);
      final result = await stanza.execute<Animal>(q);
      // 3 distinct leg counts: 0, 2, 4
      expect(result.length, 3);
    });

    test('without distinct returns all rows', () async {
      final q = SelectQuery(t)
        ..selectFields([t.legs])
        ..orderBy(t.legs);
      final result = await stanza.execute<Animal>(q);
      // 4 rows (0, 0, 2, 4)
      expect(result.length, 4);
    });

    test('distinct with where', () async {
      final q = SelectQuery(t)
        ..distinct()
        ..selectFields([t.legs])
        ..where(t.legs).isGreaterThan(0);
      final result = await stanza.execute<Animal>(q);
      // 2 distinct: 2, 4
      expect(result.length, 2);
    });
  });

  group('HAVING', () {
    test('having filters groups by aggregate', () async {
      // Group by legs, count each group, keep groups with count > 1
      final q = SelectQuery(t)
        ..selectFields([t.legs, t.id..count()..rename('cnt')])
        ..groupBy([t.legs])
        ..having(t.id..count()).isGreaterThan(1);
      final result = await stanza.execute<Animal>(q);
      // Only legs=0 has count>1 (Snake + Jellyfish)
      expect(result.length, 1);
      expect(result.first!.aggregate['cnt'], 2);
    });

    test('having with equality', () async {
      final q = SelectQuery(t)
        ..selectFields([t.legs, t.id..count()..rename('cnt')])
        ..groupBy([t.legs])
        ..having(t.id..count()).isEqualTo(1);
      final result = await stanza.execute<Animal>(q);
      // legs=2 (1 animal) and legs=4 (1 animal)
      expect(result.length, 2);
    });

    test('group by + having + order by', () async {
      final q = SelectQuery(t)
        ..selectFields([t.legs, t.id..count()..rename('cnt')])
        ..groupBy([t.legs])
        ..having(t.id..count()).isGreaterThanOrEqualTo(1)
        ..orderBy(t.legs);
      final result = await stanza.execute<Animal>(q);
      // All 3 groups (0, 2, 4) have count >= 1
      expect(result.length, 3);
    });
  });

  group('stream', () {
    test('streams all rows one by one', () async {
      final q = SelectQuery(t)
        ..selectStar()
        ..orderBy(t.name);
      final rows = <Result<Animal>>[];
      await for (final row in stanza.stream<Animal>(q)) {
        rows.add(row);
      }
      expect(rows.length, 4);
      expect(rows[0].value!.name, 'Eagle');
      expect(rows[1].value!.name, 'Jellyfish');
      expect(rows[2].value!.name, 'Snake');
      expect(rows[3].value!.name, 'Tiger');
    });

    test('streams with where clause', () async {
      final q = SelectQuery(t)
        ..selectStar()
        ..where(t.legs).isGreaterThan(0)
        ..orderBy(t.legs);
      final rows = <Result<Animal>>[];
      await for (final row in stanza.stream<Animal>(q)) {
        rows.add(row);
      }
      expect(rows.length, 2);
      expect(rows[0].value!.name, 'Eagle'); // 2 legs
      expect(rows[1].value!.name, 'Tiger'); // 4 legs
    });

    test('streams empty result set', () async {
      final q = SelectQuery(t)
        ..selectStar()
        ..where(t.name).matches('NonExistent', caseSensitive: true);
      final rows = <Result<Animal>>[];
      await for (final row in stanza.stream<Animal>(q)) {
        rows.add(row);
      }
      expect(rows, isEmpty);
    });

    test('stream within session.run', () async {
      await stanza.run((session) async {
        final q = SelectQuery(t)
          ..selectStar()
          ..orderBy(t.name);
        final rows = <Result<Animal>>[];
        await for (final row in session.stream<Animal>(q)) {
          rows.add(row);
        }
        expect(rows.length, 4);
        expect(rows.first.value!.name, 'Eagle');
      });
    });

    test('stream provides aggregate map', () async {
      final q = SelectQuery(t)
        ..selectFields([t.color, t.id..count()..rename('cnt')])
        ..groupBy([t.color])
        ..orderBy(t.color);
      final rows = <Result<Animal>>[];
      await for (final row in stanza.stream<Animal>(q)) {
        rows.add(row);
      }
      expect(rows.isNotEmpty, isTrue);
      for (final row in rows) {
        expect(row.aggregate.containsKey('cnt'), isTrue);
      }
    });
  });

  group('safety', () {
    test('delete without where throws StanzaException', () async {
      expect(
        () => stanza.execute(DeleteQuery(t)),
        throwsA(isA<StanzaException>()),
      );
    });

    test('update without where throws StanzaException', () async {
      final update = UpdateQuery(t)..column(t.color).string('red');
      expect(
        () => stanza.execute(update),
        throwsA(isA<StanzaException>()),
      );
    });
  });
}
