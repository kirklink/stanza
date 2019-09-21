
class NameConverter {
  
  String _app;
  String _json;
  String _db;
  final bool readOnly;

  NameConverter(String appName, {String jsonName, String dbName, this.readOnly: false}) {
    _app = appName;
    _json = jsonName ?? _app;
    _db = dbName ?? _app;
  }

  String get app => _app;
  String get json => _json;
  String get db => _db;

}