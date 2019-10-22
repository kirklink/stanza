abstract class Table<T> {
  String get $name;
  T fromDb(Map<String, dynamic> map);
  Map<String, dynamic> toDb(T instance);
}