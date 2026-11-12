// BuildBeacon UI — Preferences outside the browser (tests): in memory.
// Version 1.1 (2026-11-12) — comments in English.

import 'preferences.dart';

final class PlatformPreferences implements Preferences {
  final _values = <String, String>{};

  @override
  String? read(String key) => _values[key];

  @override
  void write(String key, String? value) =>
      value == null ? _values.remove(key) : _values[key] = value;
}
