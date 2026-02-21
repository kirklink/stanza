/// Regex for valid SQL identifiers: letter or underscore, then alphanumerics/underscores.
final _validIdentifier = RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]*$');

/// Validates that [name] is a safe SQL identifier.
///
/// Throws [ArgumentError] if [name] contains characters outside
/// `[a-zA-Z0-9_]` or does not start with a letter or underscore.
void assertValidIdentifier(String name, String label) {
  if (!_validIdentifier.hasMatch(name)) {
    throw ArgumentError.value(name, label, 'Not a valid SQL identifier');
  }
}
