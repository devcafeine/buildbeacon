// BuildBeacon Hub — Typed reading of JSON objects (config.json, API).
// Version 1.2 (2026-11-12) — comments in English.

import 'package:buildbeacon_plugin_sdk/buildbeacon_plugin_sdk.dart';

/// Typed access to the fields of a decoded JSON object, with translated errors.
extension JsonRead on Map<String, Object?> {
  /// Required field of type [T].
  T field<T extends Object>(String key) {
    final value = this[key];
    if (value is T) return value;
    throw value == null ? _missing(key) : _invalid<T>(key, value);
  }

  /// Optional field of type [T]; `null` if absent.
  T? optionalField<T extends Object>(String key) {
    final value = this[key];
    if (value == null) return null;
    if (value is T) return value;
    throw _invalid<T>(key, value);
  }

  /// Optional sub-object; empty if absent.
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
