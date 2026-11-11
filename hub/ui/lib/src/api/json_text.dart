// BuildBeacon UI — Textes traduits reçus du Hub ({"en": "…", "fr": "…"}).
// Version 1.0 (2026-11-11)

import 'package:buildbeacon_core/buildbeacon_core.dart';

/// `{"en": "…", "fr": "…"}` → texte traduit ; une chaîne seule vaut pour
/// toutes les langues.
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
