import 'package:stanza/annotations.dart';
import 'package:stanza/stanza.dart';

part 'example.g.dart';

@StanzaEntity(name: 'mammal', snakeCase: true)
class Animal {
  @StanzaField(readOnly: true)
  late int id;
  late String name;
  @StanzaField(name: 'number_of_legs')
  late int legs;
  late String color;
  late DateTime createdAt;

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

  await stanza.close();
}
