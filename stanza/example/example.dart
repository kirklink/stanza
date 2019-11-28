import 'package:stanza/annotations.dart';
import 'package:stanza/stanza.dart';

part 'example.g.dart';

@StanzaEntity(name: 'mammal', snakeCase: true)
class Animal {
    @StanzaField(readOnly: true)
    int id;
    String name;
    @StanzaField(name: 'number_of_legs')
    int legs;
    String color;
    DateTime createdAt;

    Animal();

    static _$AnimalTable $table = _$AnimalTable();
}

main() async {
  
  var creds = PostgresCredentials(
    'localhost',
    5432,
    'databaseName',
    'userName',
    'dbPassword'
  );

  var stanza = Stanza(creds);
  
  var animal = Animal()
    ..name = 'Tiger'
    ..legs = 4
    ..color = 'orange'
    ..createdAt = DateTime.now().toUtc();
  
  var insertQuery = InsertQuery(Animal.$table)
    ..insertEntity<Animal>(animal);

  var connection = await stanza.connection();
  await connection.execute(insertQuery, autoClose: false);

  var selectQuery = SelectQuery(Animal.$table)
    ..selectFields([Animal.$table.name, Animal.$table.color])
    ..where(Animal.$table.legs).isGreaterThanOrEqualTo(4)
    ..and(Animal.$table.color).matches('orange')
    ..limit(1);
  
  var result = await connection.execute<Animal>(selectQuery);
  print("The ${result.first.value.name} is ${result.first.value.color}"); // The Tiger is orange.

}