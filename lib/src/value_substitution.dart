class ValueSub {

  String _key;
  dynamic _value;
  String _token;

  ValueSub(String name, dynamic value) {
    // _key = name + '_' + count.toString();
    // _sub = '@' + _key;

    _key = name + '_' + value.hashCode.toString();
    _token = '@' + name + '_' + value.hashCode.toString();
    _value = value;
  }

  String get key => _key;
  dynamic get value => _value;
  String get token => _token;

}