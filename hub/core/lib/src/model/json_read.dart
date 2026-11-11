// BuildBeacon Hub — Lecture typée des objets JSON (config.json, API).
// Version 1.1 (2026-11-11) — erreurs traduites (LocalizedFormatException).

import 'package:buildbeacon_plugin_sdk/buildbeacon_plugin_sdk.dart';

/// Accès typés aux champs d'un objet JSON décodé, avec des erreurs traduites.
extension JsonRead on Map<String, Object?> {
  /// Champ obligatoire de type [T].
  T field<T extends Object>(String key) {
    final value = this[key];
    if (value is T) return value;
    throw value == null ? _missing(key) : _invalid<T>(key, value);
  }

  /// Champ facultatif de type [T] ; `null` s'il est absent.
  T? optionalField<T extends Object>(String key) {
    final value = this[key];
    if (value == null) return null;
    if (value is T) return value;
    throw _invalid<T>(key, value);
  }

  /// Sous-objet facultatif ; vide s'il est absent.
  Map<String, Object?> objectField(String key) =>
      optionalField<Map<String, Object?>>(key) ?? const {};

  static LocalizedFormatException _missing(String key) =>
      LocalizedFormatException(
        LocalizedText.build(
          (l) =>
              tr(l, en: 'Missing field "$key"', fr: 'Champ « $key » manquant'),
        ),
      );

  static LocalizedFormatException _invalid<T>(String key, Object value) =>
      LocalizedFormatException(
        LocalizedText.build(
          (l) => tr(
            l,
            en: 'Invalid field "$key": $T expected, found "$value"',
            fr: 'Champ « $key » invalide : $T attendu, « $value » trouvé',
          ),
        ),
      );
}
