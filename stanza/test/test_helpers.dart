import 'package:stanza/stanza.dart';

/// Simple entity class for testing.
class Animal {
  int id = 0;
  String name = '';
  int legs = 0;
  String color = '';
  int ownerId = 0;
  int habitatId = 0;

  static final $table = AnimalTable();
}

/// Mock table that mimics generated code.
class AnimalTable extends Table<Animal> {
  @override
  final String $name = 'mammal';

  @override
  final Type $type = Animal;

  Field get id => Field('mammal', 'id');
  Field get name => Field('mammal', 'name');
  Field get legs => Field('mammal', 'number_of_legs');
  Field get color => Field('mammal', 'color');
  Field get ownerId => Field('mammal', 'owner_id');
  Field get habitatId => Field('mammal', 'habitat_id');

  @override
  Animal fromDb(Map<String, dynamic> map) {
    return Animal()
      ..id = map['id'] as int
      ..name = map['name'] as String
      ..legs = map['number_of_legs'] as int
      ..color = map['color'] as String;
  }

  @override
  Map<String, dynamic> toDb(Animal instance) {
    return <String, dynamic>{
      'name': instance.name,
      'number_of_legs': instance.legs,
      'color': instance.color,
    };
  }

  // --- BelongsTo: Owner via ownerId (mimics generated code) ---

  List<Field> get _ownerJoinFields => [
        Field('owner', 'id')..rename('owner__id'),
        Field('owner', 'name')..rename('owner__name'),
      ];

  void innerJoinOwner(SelectQuery q) {
    q.selectFields(_ownerJoinFields);
    q.innerJoin(Owner.$table).on(ownerId, Field('owner', 'id'));
  }

  void leftJoinOwner(SelectQuery q) {
    q.selectFields(_ownerJoinFields);
    q.leftJoin(Owner.$table).on(ownerId, Field('owner', 'id'));
  }

  Owner? ownerFromRow(Map<String, dynamic> row) {
    if (row['owner__id'] == null) return null;
    return Owner()
      ..id = row['owner__id'] as int
      ..name = row['owner__name'] as String;
  }
}

/// Owner entity for join testing.
class Owner {
  int id = 0;
  String name = '';

  static final $table = OwnerTable();
}

/// Mock owner table for join testing.
class OwnerTable extends Table<Owner> {
  @override
  final String $name = 'owner';

  @override
  final Type $type = Owner;

  Field get id => Field('owner', 'id');
  Field get name => Field('owner', 'name');

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

/// Habitat entity for multi-join testing.
class Habitat {
  int id = 0;
  String biome = '';

  static final $table = HabitatTable();
}

/// Mock habitat table for multi-join testing.
class HabitatTable extends Table<Habitat> {
  @override
  final String $name = 'habitat';

  @override
  final Type $type = Habitat;

  Field get id => Field('habitat', 'id');
  Field get biome => Field('habitat', 'biome');

  @override
  Habitat fromDb(Map<String, dynamic> map) {
    return Habitat()
      ..id = map['id'] as int
      ..biome = map['biome'] as String;
  }

  @override
  Map<String, dynamic> toDb(Habitat instance) {
    return <String, dynamic>{
      'biome': instance.biome,
    };
  }
}
