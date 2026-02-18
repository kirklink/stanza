/// Not to be used directly. Converts values to tokens that are used by the PostgreSQL database
/// connection library's named parameter substitution.
class ValueSub {
  static int _counter = 0;

  final String key;
  final dynamic value;
  final String token;

  ValueSub(String name, this.value)
      : key = '${name}_$_counter',
        token = '@${name}_$_counter' {
    _counter++;
  }
}
