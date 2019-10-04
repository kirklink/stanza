import 'package:reflectable/reflectable.dart';


class StanzaField {
  final String name;
  final bool exclude;
  final bool readOnly;
  const StanzaField({this.name, this.exclude, this.readOnly});
}

class StanzaTable extends Reflectable {
  final String name;
  const StanzaTable({this.name}) : super(metadataCapability);
}
