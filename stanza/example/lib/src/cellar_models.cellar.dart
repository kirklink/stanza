// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:cellar/cellar.dart';

/// Cellar collection schema for `Episode`.
///
/// Pass to `Cellar.open(collections: [...])` for table management.
const $episodeCollection = CellarCollection(
  name: 'episodes',
  fields: [
    CellarField.text('content', fts: true),
    CellarField.text('type'),
    CellarField.real('importance'),
    CellarField.bool('consolidated'),
  ],
);

/// Cellar collection schema for `Setting`.
///
/// Pass to `Cellar.open(collections: [...])` for table management.
const $settingCollection = CellarCollection(
  name: 'app_settings',
  fields: [
    CellarField.text('key'),
    CellarField.text('value', nullable: true),
  ],
  indexes: [
    CellarIndex(['key']),
  ],
);

