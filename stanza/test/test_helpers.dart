import 'package:stanza/stanza.dart';

/// Simple entity class for testing.
class Animal {
  int id = 0;
  String name = '';
  int legs = 0;
  String color = '';

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
}
