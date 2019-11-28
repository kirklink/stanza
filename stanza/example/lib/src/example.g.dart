// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'example.dart';

// **************************************************************************
// StanzaEntityGenerator
// **************************************************************************

class _$AnimalTable extends Table<Animal> {
  final String $name = 'mammal';
  final Type $type = Animal;

  Field get id => Field('mammal', 'id');
  Field get name => Field('mammal', 'name');
  Field get legs => Field('mammal', 'number_of_legs');
  Field get color => Field('mammal', 'color');
  Field get createdAt => Field('mammal', 'created_at');

  Animal fromDb(Map<String, dynamic> map) {
    return Animal()
      ..id = map['id'] as int
      ..name = map['name'] as String
      ..legs = map['number_of_legs'] as int
      ..color = map['color'] as String
      ..createdAt = map['created_at'] as DateTime;
  }

  Map<String, dynamic> toDb(Animal instance) {
    return <String, dynamic>{
      'name': instance.name,
      'number_of_legs': instance.legs,
      'color': instance.color,
      'created_at': instance.createdAt,
    };
  }
}
