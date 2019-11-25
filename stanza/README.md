# stanza

## overview
Stanza is a library for writing basic Postgresql statements in a type safe, Dart-y syntax. The goal has been to keep the API simple and clear while speeding up construction of Postgresql queries when using Dart on the server. It started as a hobby project but evolved enough to make it potentially useful to others. If you are interested in contributing to this library, please get in touch.

## what it is
Stanza sits on top of [Stable Kernel's postgresql-dart](https://github.com/stablekernel/postgresql-dart) library for it's database connection. Further, it leverages some of existing functionality, such as type conversions and transactions, to interact with a Postgresql database. This library, and the companion stanza_builder library, add a layer of code generation to help structure Dart class models and compose simple queries using the type safe properties of the Dart class.

## what it is not
Stanza is not an ORM and does not directly manage database objects (i.e., creating tables or performing migrations) although does provide a type safe interface between Dart classes and the database. There is currently no magic around query optimization or even joins although the API is planned to include joins. Heck, there isn't even delete query support yet because the initial use case was a purely additive-only database, although this should be a relatively easy expansion. It is simple but does offer a user-friendly API for the queries it supports and makes interacting with a database easier.

## how to use it
### annotate a class
Include stanza as a dependency and stanza_builder as a dev dependency in the pubspec.yaml file. build_runner is also a dev dependency to run the code generation.

```yaml
...
dependencies:
  stanza: '^0.0.8'
dev_dependencies:
  build_runner: any
  stanza_builder: '^0.0.8'
...
```

Create a model class to mirror your database structure and annotate the class with stanza decorations.

```dart
import 'package:stanza/annotations.dart';

part 'animal.g.dart';

@StanzaEntity(name: 'mammal', snakeCase: true)
class Animal {
    @StanzaField(readOnly: true)
    int id;
    String name;
    @StanzaField(name: 'number_of_legs')
    int legs;
    String color;
    Datetime createdAt;

    Animal();

    static _$AnimalTable $table = _$AnimalTable();
}
```

The example above outlines the options that are currently available.
* `StanzaEntity(name: 'mammal')` means that the class will be renamed to correspond with a different database table name (in this case, the table name is 'mammal').
* `StazaEntity(snakeCase: true)` means that the entity and all members, that don't have an explicit 'name' parameter, will be re-written in snake_case to correspond with database fields. For example, the class property createdAt will be renamed created_at. However, the property legs will not be re-written to snake_case because it has an explicit name parameter.
* `StanzaField(name: 'number_of_legs')` means that the field will be renamed to correspond with a different field name in the database (in this case, the field is 'number_of_legs').
* `StanzaField(readOnly: true)` means that the Dart model will not write this property to the database, but it will retrieve this property from the database. It's a simple way to handle fields that are generated in the database, especially incremented id's.
* `static _$AnimalTable $table = _$AnimalTable();` comes from the generated code and produces the interface to interact with a database table. "Table" is appended to the class name to create the table interaction class and by convention it is called `$table` to indicate it is a generated property.
 
 Don't forget to import the generated code with `part 'animal.g.dart';`, which will earn an exception if it isn't included.
 
 Stanza plays nice with other generated code, such as json_serializable, so you can use the same `part` statement and reach all the generated code and have both a front-/back-end interface via json_serializable and a database interface via stanza through the same Dart model class.

 Run `pub run build_runner build` to generate the Stanza code. A file called 'original_file_name.g.dart' will be created which is automatically "appended" to the original fine with the `part` statement.

### set up the database credentials
Create a `PostgresCredentials` object with the details of the database connection:

```dart
final creds = PostgresCredentials(
  hostnameOrIp,
  portNumber,
  databaseName,
  username,
  databasePassword
);
```

As a side note, there are some ways to make this more reusable, such as creating a class that reproduces creds when needed. For example:

```dart
class DbCreds {
  static String _host = 'hostname';
  static int _port = 5432;
  static String _db = 'databaseName';
  static String _user = 'userName';
  static String _password = 'somethingSecure';
  static PostgresCredentials creds = {
    return PostgresCredentials(
      DbCreds._host,
      DbCreds._port,
      DbCreds._db,
      DbCreds._user,
      DbCreds._password
    );
  };
}
```

There are other, better ways of achieving this repeatability, especially if some of the properties are being pulled from the environment, such as the database password. But this is a starting point.

### create a stanza instance

```dart
import 'package:stanza/stanza.dart';

...
var stanza = Stanza(creds, maxConnections: 20, timeout: 300);
...
```

Note that 'timeout' is in seconds.

The defaults are 25 maxConnections and 600 seconds timeout.

The database interface is cached so the first time it is initiated, the parameters are set and the same paramaters are used for future instances. The interface is identified by the host, port, and database and the connections are pooled, so Stanza will not go over the maxConnections that are originally set if the same database interface is called multiple times. It also means multiple databases can be called from Stanza and they will each get their own cached parameters within Stanza.

### build a query

```dart
var table = Animal.$table;

var select = SelectQuery(table)
  ..selectFields([table.id, table.legs, table.color, table.createdAt])
  ..where(table.legs).greaterThan(2)
  ..and(table.color).matches('brown')
  ..orderBy(table.id, descending: true)
  ..limit(10);
```

The API for building queries is much what one would expect and there are several conveniences built in.

* SelectQuery
  * `var selectQuery = SelectQuery(table)`
  * `..selectFields([table.fieldName])` -> a list of fields to select from the table
  * `..selectStar()` -> select all the fields from the table
  * `..where(table.fieldName)`, `..and(table.fieldName)`, `..or(table.fieldName)` -> composable conditional clauses that currently supports :
    * `.isNotNull()`
    * `.isNull()`
    * `.equalTo(num number)`
    * `.greaterThan(num number)`
    * `.greaterThanOrEqualTo(num number)`
    * `.lessThan(num number)`
    * `.lessThanOrEqualTo(num number)`
    * `.matches(String string, {bool caseSensitive: false})`
    * `.startsWith(String string, {bool caseSensitive: false})`
    * `.endsWith(String string, {bool caseSensitive: false})`
    * `.contains(String string, {bool caseSensitive: false})`
    * `.isTrue()`
    * `.isFalse()`
    * `.isBefore(DateTime date)`
    * `.isAfter(DateTime date)`
    * `.isOn(DateTime date)`
  * where/and/or clauses can also include opening and closing brackets to group clauses together
    * 
    ```dart
    ..where(table.firstName).startsWith('e')
    ..and(table.age).lessThan(20, openBracket: true)
    ..or(table.age).greaterThan(40, closeBracket: true)
    ```
    * there is some simple checking for opened and closed brackets that will help limit errors when bracketing
  * `..groupBy([table.fieldName])`
  * `..orderBy(table.fieldName)`
    * Multiple orderBy clauses can be provided and can be made descending with `..orderBy(table.fieldName, descending: true)`
  * `..offset(10)` -> the number of records to offset
  * `..limit(10)` -> the number of results to return
* InsertQuery
  * `var insertQuery = InsertQuery(table)`
  * `..insert(table.fieldName, value)` -> insert a dynamic value into a field; this is composable and multiple fields can be inserted into the database
  * OR `..insertEntity<type>(entity)` -> will insert a complete model class and providing the type will ensure that only an intended class type is inserted
* UpdateQuery
  * `var updateQuery = UpdateQuery(table)`
  * `..column(table.fieldName)` -> the target database field
  * One of the following can be used to restrict the type supplied:
    * `.number(num number)`
    * `.integer(int integer)`
    * `.float (double float)`
    * `.string(String string)`
    * `.datetime(DateTime datetime)`
    * `.boolean(bool boolean)`
  * Or a dynamic value can be provided with:
    * `.any(dynamic value)`
  * `..where(table.fieldName)` -> specify the conditions where the value(s) should be updated. See the where/and/or clause usage above under SelectQuery





### run the query
When the program is ready to run the query, a connection obtained from Stanza, respecting the maxConnections configured, and the query can be executed.

```dart
var connection = await Stanza.connection();
var result = await connection.execute<type>(query);
```

The result here is a list of the Dart class being queries and any associated aggregations (covered later). The query results can be accessed in a couple ways:

`result.all` is the full list of results
`result.first` is the first result

Each individual result contains a `.value`, which has all the properties of the original Dart class. It also contains a `.aggregate` if applicable, that has the results of query aggregates, if applicable.

Going back to the original `Animal` class example above, we could cycle through the query results as follows (assuming we have built a select query, called animalSelectQuery, to select a bunch of animals from the database):

```dart
var result = await connection.execute<Animal>(animalSelectQuery);
for (var animal in result.all) {
  print(animal.value.name);
}
```
This will print all the animal names to the console.

### use aggregates in a query
### execute a query in a transaction
### print a query
### fork a query