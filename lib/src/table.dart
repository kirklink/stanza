import 'dart:mirrors';

import 'package:json_annotation/json_annotation.dart';

import 'package:stanza/src/exception.dart';
import 'package:stanza/src/annotations.dart';
import 'package:stanza/src/name_converter.dart';
import 'package:stanza/src/adapter_field.dart';
import 'package:stanza/src/field.dart';


class Table<T> {

  var _fields = Map<String, NameConverter>();
  NameConverter _tableName;

  bool _hasToJson = false;
  bool _hasFromJson = false;

  String get appName => _tableName.app;
  String get jsonName => _tableName.json;
  String get dbName => _tableName.db;


  Table() {
    var t = reflectClass(T);
    String tableName;
    // Look for a provided table name in class metadata
    for (var i in t.metadata) {
      var j = i.reflectee;
      if (j is DbTable) {
        tableName = j.name;
      }
    }
    // get the entity name
    var className = MirrorSystem.getName(t.simpleName);
    // set the table name with 'translation'
    _tableName = NameConverter(className, dbName: tableName);
    var fromJsonCheck = className + '.fromJson';
    for (var decMirror in t.declarations.values) {
      if (decMirror.isPrivate) continue;
      var simpleName = MirrorSystem.getName(decMirror.simpleName);
      // Check if the entity implements toJson and fromJson
      if (!_hasFromJson) _hasFromJson = (simpleName == fromJsonCheck);
      if (!_hasToJson) _hasToJson = (simpleName == 'toJson');
      // Only allow setters and getters as valid fields
      var getter = t.instanceMembers[decMirror.simpleName];
      var setter = t.instanceMembers[Symbol(simpleName+'=')];
      var isGetter = (getter?.isSynthetic ?? false) || (getter?.isGetter ?? false);
      var isSetter = (setter?.isSynthetic ?? false) || (setter?.isSetter ?? false);
      var isGetterAndSetter = isGetter && isSetter;
      if (!isGetterAndSetter) continue;
      // Skip constructors
      var qualName = MirrorSystem.getName(decMirror.qualifiedName);
      var isContructor = qualName.split(className).length > 2;
      if (isContructor) continue;
      // Process the field metadata
      String dbField;
      String jsonField;
      bool skip = false;
      bool readOnly = false;
      for (var im in decMirror.metadata) {
        var r = im.reflectee;
        // Look at DbField metadata
        if (r is DbField) {
          // Get the db field name
          dbField = r.name;
          // Exclude if appropriate
          skip = r.exclude ?? false;
          // Set read only if appropriate
          if (r.readOnly == true) readOnly = true;
        }
        // Look at JsonKey metadata (from JsonSerializable)
        if (r is JsonKey) {
          // Get the json field name
          jsonField = r?.name;
        }
      }
      if (skip) continue;
      // if everything passes, add the field to allowed fields with name 'translations'
      var cf = NameConverter(MirrorSystem.getName(decMirror.simpleName), 
        dbName: dbField, jsonName: jsonField, readOnly: readOnly);
      _fields[cf.app] = cf;
    }
    // If the entity doesn't implement toJson and fromJson; throw!
    if (!_hasToJson || !_hasFromJson) {
      throw QueryException('An entity must implement "toJson" and "fromJson". Class "$className" does not.');
    }
  }


  Map<String, dynamic> dbToJsonAdapter(Map<String, dynamic> dbEntity) {
    var converted = Map<String, dynamic>();
    for (var name in _fields.values) {
      var obj = dbEntity[name.db];
      if (obj is DateTime) obj = obj.toString();
      converted[name.json] = obj;
    }
    return converted;
  }

  Map<String, dynamic> jsonToDbAdapter(Map<String, dynamic> jsonEntity) {
    var converted = Map<String, dynamic>();
    for (var name in _fields.values) {
      if (name.readOnly) continue;
      converted[name.db] = jsonEntity[name.json];
    }
    return converted;
  }

  Field field(AdapterField<T> field) {
    dynamic _mock;
    try {
      field(_mock);
    } catch (e) {
      var fieldToTry = e.toString().split('Tried calling: ')[1].split(' ')[0];
      var existingField = _fields[fieldToTry];
      if (existingField == null) {
        throw QueryException('An invalid field name was used: $fieldToTry');
      };
      return(Field(existingField, _tableName.db));
    }
    throw QueryException('Could not create a query statement. Class field name(s) could not be retrieved.');
  }




}