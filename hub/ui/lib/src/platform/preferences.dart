// BuildBeacon UI — Preferences of this browser (chosen language).
// Version 1.1 (2026-11-12) — comments in English.

import 'preferences_io.dart'
    if (dart.library.js_interop) 'preferences_web.dart'
    as platform;

/// Small preferences specific to this browser (localStorage); in memory
/// outside the browser. A failed read (private browsing, blocked storage)
/// returns `null`: the interface still works.
abstract interface class Preferences {
  factory Preferences() = platform.PlatformPreferences;

  String? read(String key);

  void write(String key, String? value);
}
