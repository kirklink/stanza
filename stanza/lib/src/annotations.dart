class StanzaEntity {  
  final String name;  
  final bool snakeCase;   
  const StanzaEntity({this.name, this.snakeCase: false});
}

class StanzaField {
  final String name;
  final bool readOnly;
  const StanzaField({this.name, this.readOnly : false});
}