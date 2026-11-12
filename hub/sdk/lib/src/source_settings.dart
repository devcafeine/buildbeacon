// BuildBeacon Hub — Plugin SDK: typed access to the settings of a source.
// Version 1.2 (2026-11-12) — comments in English.

/// Settings of a source, with typed access.
///
/// The Hub has validated them against `SourcePlugin.settings` before handing
/// them to the plugin: a `required` setting is present and of the right type.
/// Reading a missing setting, or one of the wrong type, is therefore a bug in
/// the plugin ([StateError], with a message in English for developers).
final class SourceSettings {
  SourceSettings(Map<String, Object?> values)
    : values = Map.unmodifiable(values);

  /// Raw values, as in config.json.
  final Map<String, Object?> values;

  String text(String id) => _required<String>(id, 'text');

  String? optionalText(String id) => _optional<String>(id, 'text');

  int integer(String id) => _required<int>(id, 'an integer');

  int? optionalInteger(String id) => _optional<int>(id, 'an integer');

  double number(String id) => _required<num>(id, 'a number').toDouble();

  double? optionalNumber(String id) =>
      _optional<num>(id, 'a number')?.toDouble();

  /// Yes/no setting; [orElse] if it is missing.
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
