
class DbField {
  final String name;
  final bool exclude;
  final bool readOnly;
  const DbField({this.name, this.exclude, this.readOnly});
}

class DbTable {
  final String name;
  const DbTable({this.name});
}
