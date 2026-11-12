// BuildBeacon UI — Translated texts received from the Hub ({"en": "…", "fr": "…"}).
// Version 1.1 (2026-11-12) — comments in English.

import 'package:buildbeacon_core/buildbeacon_core.dart';

/// `{"en": "…", "fr": "…"}` → translated text; a plain string applies to
/// all languages.
LocalizedText localizedFromJson(Object? json) => switch (json) {
  final Map<String, Object?> map => LocalizedText({
    for (final MapEntry(:key, :value) in map.entries)
      if (value is String) key: value,
  }),
  final String text => LocalizedText.same(text),
  _ => const LocalizedText.same(''),
};

LocalizedText? optionalLocalized(Object? json) =>
    json == null ? null : localizedFromJson(json);

List<LocalizedText> localizedList(Object? json) => [
  if (json is List<Object?>)
    for (final item in json) localizedFromJson(item),
];
