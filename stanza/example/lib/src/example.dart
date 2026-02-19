import 'package:stanza/annotations.dart';
import 'package:stanza/stanza.dart';

part 'example.g.dart';

@StanzaEntity(snakeCase: true)
class Owner {
  @PrimaryKey()
  @StanzaField(readOnly: true)
  late int id;
  @StanzaField(unique: true)
  late String name;

  Owner();

  static final _$OwnerTable $table = _$OwnerTable();
}

@StanzaEntity(name: 'mammal', snakeCase: true)
class Animal {
  @PrimaryKey()
  @StanzaField(readOnly: true)
  late int id;
  late String name;
  @StanzaField(name: 'number_of_legs')
  late int legs;
  late String color;
  late DateTime createdAt;

  @BelongsTo(Owner, onDelete: 'CASCADE')
  late int ownerId;

  Animal();

  static final _$AnimalTable $table = _$AnimalTable();
}

void main() async {
  // --- Connect ---
  // From a connection URL (recommended for cloud providers):
  // var stanza = Stanza.url('postgresql://user:pass@host/db?sslmode=require');

  // From explicit credentials:
  var creds = PostgresCredentials(
      'localhost', 5432, 'databaseName', 'userName', 'dbPassword');
  var stanza = Stanza.tcp(creds, maxConnections: 10);

  var t = Animal.$table;

  // --- INSERT a single entity with RETURNING ---
  var animal = Animal()
    ..name = 'Tiger'
    ..legs = 4
    ..color = 'orange'
    ..createdAt = DateTime.now().toUtc();

  var insertQuery = InsertQuery(t)
    ..insertEntity<Animal>(animal)
    ..returningStar();
  var inserted = await stanza.execute<Animal>(insertQuery);
  print('Inserted: ${inserted.first?.value?.name}');

  // --- Batch INSERT ---
  var batchQuery = InsertQuery(t)
    ..insertEntities<Animal>([
      Animal()..name = 'Eagle'..legs = 2..color = 'brown'..createdAt = DateTime.now().toUtc(),
      Animal()..name = 'Snake'..legs = 0..color = 'green'..createdAt = DateTime.now().toUtc(),
    ])
    ..returningStar();
  var batch = await stanza.execute<Animal>(batchQuery);
  print('Batch inserted ${batch.length} animals');

  // --- Upsert (ON CONFLICT DO UPDATE) ---
  var upsertQuery = InsertQuery(t)
    ..insertEntity<Animal>(animal)
    ..onConflict(
      target: [t.name],
      doUpdate: (set) => set..column(t.color).string('updated-orange'),
    )
    ..returningStar();
  await stanza.execute<Animal>(upsertQuery);

  // --- ON CONFLICT DO NOTHING ---
  var skipQuery = InsertQuery(t)
    ..insertEntity<Animal>(animal)
    ..onConflictDoNothing(target: [t.name]);
  await stanza.execute(skipQuery);

  // --- SELECT with WHERE, IN, ORDER BY, LIMIT ---
  var selectQuery = SelectQuery(t)
    ..selectStar()
    ..where(t.legs).isGreaterThanOrEqualTo(2)
    ..and(t.color).isIn(['orange', 'brown'])
    ..orderBy(t.name)
    ..limit(10);
  var result = await stanza.execute<Animal>(selectQuery);
  for (var r in result.entities) {
    print('${r.name}: ${r.legs} legs, ${r.color}');
  }

  // --- SELECT DISTINCT ---
  var distinctQuery = SelectQuery(t)
    ..distinct()
    ..selectFields([t.color]);
  await stanza.execute<Animal>(distinctQuery);

  // --- GROUP BY + HAVING ---
  var aggQuery = SelectQuery(t)
    ..selectFields([t.color, t.id..count()..rename('animal_count')])
    ..groupBy([t.color])
    ..having(t.id..count()).isGreaterThan(1);
  var aggResult = await stanza.execute<Animal>(aggQuery);
  for (var r in aggResult.all) {
    print('${r.aggregate['animal_count']} ${r.value?.color} animals');
  }

  // --- JOIN with typed result mapping (@BelongsTo) ---
  var joinQuery = SelectQuery(t)..selectStar();
  t.innerJoinOwner(joinQuery);
  joinQuery.where(t.legs).isGreaterThan(0);
  var joinResult = await stanza.execute<Animal>(joinQuery);
  for (final row in joinResult.all) {
    var a = row.value;
    var owner = t.ownerFromRow(row.aggregate);
    print('${a?.name} belongs to ${owner?.name}');
  }

  // --- UPDATE with RETURNING ---
  var updateQuery = UpdateQuery(t)
    ..column(t.color).string('white')
    ..where(t.name).matches('Tiger', caseSensitive: true)
    ..returningStar();
  await stanza.execute<Animal>(updateQuery);

  // --- DELETE ---
  var deleteQuery = DeleteQuery(t)
    ..where(t.name).matches('Snake', caseSensitive: true);
  await stanza.execute(deleteQuery);

  // --- Transaction (auto-rollback on error) ---
  await stanza.runTransaction((session) async {
    await session.execute(insertQuery);
    return session.execute<Animal>(selectQuery);
  });

  // --- Raw SQL ---
  await stanza.rawExecute(
    'INSERT INTO mammal (name, number_of_legs, color) VALUES (@name, @legs, @color)',
    parameters: {'name': 'Dolphin', 'legs': 0, 'color': 'grey'},
  );

  // --- Fork a query for dynamic patterns ---
  var base = SelectQuery(t)
    ..selectStar()
    ..where(t.legs).isGreaterThan(0);
  for (var color in ['orange', 'brown']) {
    var q = base.fork()..and(t.color).matches(color);
    var r = await stanza.execute<Animal>(q);
    print('$color: ${r.length} animals');
  }

  await stanza.close();
}
