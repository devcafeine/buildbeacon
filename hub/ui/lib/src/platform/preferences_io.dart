// BuildBeacon UI — Préférences hors navigateur (tests) : en mémoire.
// Version 1.0 (2026-11-11)

import 'preferences.dart';

final class PlatformPreferences implements Preferences {
  final _values = <String, String>{};

  @override
  String? read(String key) => _values[key];

  @override
  void write(String key, String? value) =>
      value == null ? _values.remove(key) : _values[key] = value;
}
