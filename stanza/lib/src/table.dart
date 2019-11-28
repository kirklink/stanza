/// The class on which generated tables are based.
abstract class Table<T> {
  String get $name;
  Type get $type;
  T fromDb(Map<String, dynamic> map);
  Map<String, dynamic> toDb(T instance);
}