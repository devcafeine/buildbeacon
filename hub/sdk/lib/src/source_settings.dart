// BuildBeacon Hub — SDK des plugins : accès typé aux réglages d'une source.
// Version 1.1 (2026-11-11) — messages d'erreur de programmation en anglais.

/// Réglages d'une source, avec un accès typé.
///
/// Le Hub les a validés selon `SourcePlugin.settings` avant de les donner au
/// plugin : un réglage `required` est présent et du bon type. Lire un
/// réglage absent ou du mauvais type est donc une erreur du plugin
/// ([StateError], message en anglais pour les développeurs).
final class SourceSettings {
  SourceSettings(Map<String, Object?> values)
    : values = Map.unmodifiable(values);

  /// Valeurs brutes, telles que dans config.json.
  final Map<String, Object?> values;

  String text(String id) => _required<String>(id, 'text');

  String? optionalText(String id) => _optional<String>(id, 'text');

  int integer(String id) => _required<int>(id, 'an integer');

  int? optionalInteger(String id) => _optional<int>(id, 'an integer');

  double number(String id) => _required<num>(id, 'a number').toDouble();

  double? optionalNumber(String id) =>
      _optional<num>(id, 'a number')?.toDouble();

  /// Réglage oui/non ; [orElse] s'il est absent.
  bool flag(String id, {bool orElse = false}) =>
      _optional<bool>(id, 'a boolean') ?? orElse;

  T _required<T extends Object>(String id, String expected) =>
      _optional<T>(id, expected) ??
      (throw StateError(
        'Setting "$id" is missing: declare it as required in settings, '
        'or read it with the optional… accessor',
      ));

  T? _optional<T extends Object>(String id, String expected) {
    final value = values[id];
    if (value == null || value is T) return value as T?;
    throw StateError('Setting "$id": $expected expected, found "$value"');
  }

  @override
  String toString() => 'SourceSettings($values)';
}
