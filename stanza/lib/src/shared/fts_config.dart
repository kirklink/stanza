/// PostgreSQL text search configuration.
///
/// Specifies the language dictionary for stemming, stop words, and
/// normalization when using full-text search operations.
enum FtsConfig {
  simple('simple'),
  english('english'),
  spanish('spanish'),
  french('french'),
  german('german'),
  italian('italian'),
  portuguese('portuguese'),
  russian('russian'),
  swedish('swedish'),
  turkish('turkish'),
  dutch('dutch'),
  danish('danish'),
  finnish('finnish'),
  hungarian('hungarian'),
  norwegian('norwegian'),
  romanian('romanian');

  final String value;
  const FtsConfig(this.value);
}

/// The type of tsquery parser to use for full-text search.
enum FtsQueryType {
  /// Converts plain text to a tsquery, connecting words with &.
  ///
  /// Input: `'fat cats'` produces `'fat' & 'cats'`
  plain,

  /// Google-like search syntax with quoting, negation, and OR.
  ///
  /// Input: `'"fat cats" -dogs'` produces `'fat' <-> 'cats' & !'dogs'`
  websearch,

  /// Words must appear in the given order (proximity search).
  ///
  /// Input: `'fat cats'` produces `'fat' <-> 'cats'`
  phrase,
}
