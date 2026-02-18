import 'package:stanza/annotations.dart';
import 'package:stanza/stanza.dart';

part 'example.g.dart';

@StanzaEntity(snakeCase: true)
class Owner {
  @StanzaField(readOnly: true)
  late int id;
  late String name;

  Owner();

  static final _$OwnerTable $table = _$OwnerTable();
}

@StanzaEntity(name: 'mammal', snakeCase: true)
class Animal {
  @StanzaField(readOnly: true)
  late int id;
  late String name;
  @StanzaField(name: 'number_of_legs')
  late int legs;
  late String color;
  late DateTime createdAt;

  @BelongsTo(Owner)
  late int ownerId;

  Animal();

  static final _$AnimalTable $table = _$AnimalTable();
}

void main() async {
  var creds = PostgresCredentials(
      'localhost', 5432, 'databaseName', 'userName', 'dbPassword');

  var stanza = Stanza.tcp(creds, maxConnections: 10);

  var animal = Animal()
    ..name = 'Tiger'
    ..legs = 4
    ..color = 'orange'
    ..createdAt = DateTime.now().toUtc();

  var insertQuery = InsertQuery(Animal.$table)..insertEntity<Animal>(animal);

  // Simple single-query execution:
  await stanza.execute(insertQuery);

  var selectQuery = SelectQuery(Animal.$table)
    ..selectFields([Animal.$table.name, Animal.$table.color])
    ..where(Animal.$table.legs).isGreaterThanOrEqualTo(4)
    ..and(Animal.$table.color).matches('orange')
    ..limit(1);

  var result = await stanza.execute<Animal>(selectQuery);
  print(
      'The ${result.first?.value?.name} is ${result.first?.value?.color}');

  // Multi-query on one session:
  await stanza.run((session) async {
    await session.execute(insertQuery);
    return session.execute<Animal>(selectQuery);
  });

  // Transaction (auto-rollback on error):
  await stanza.runTransaction((session) async {
    await session.execute(insertQuery);
    return session.execute<Animal>(selectQuery);
  });

  // Join query with typed result mapping:
  var joinQuery = SelectQuery(Animal.$table)..selectStar();
  Animal.$table.innerJoinOwner(joinQuery);
  joinQuery.where(Animal.$table.legs).isGreaterThan(2);

  var joinResult = await stanza.execute<Animal>(joinQuery);
  for (final row in joinResult.all) {
    var a = row.value;
    var owner = Animal.$table.ownerFromRow(row.aggregate);
    print('${a?.name} belongs to ${owner?.name}');
  }

  await stanza.close();
}
