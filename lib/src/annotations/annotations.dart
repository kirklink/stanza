class StanzaEntity {  
  final String name;  
  final bool snakeCase;   
  const StanzaEntity(this.name, {this.snakeCase: false}) : assert(name != null);
}

class StanzaField {
  final String name;
  final bool readOnly;
  const StanzaField({this.name, this.readOnly : false});
}
