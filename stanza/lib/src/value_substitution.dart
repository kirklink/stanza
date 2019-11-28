/// Not to be used directly. Converts values to tokens that are used by the Postgresql database
/// connection library.
class ValueSub {

  String _key;
  dynamic _value;
  String _token;

  ValueSub(String name, dynamic value) {
    _key = name + '_' + value.hashCode.toString();
    _token = '@' + name + '_' + value.hashCode.toString();
    _value = value;
  }

  String get key => _key;
  dynamic get value => _value;
  String get token => _token;

}