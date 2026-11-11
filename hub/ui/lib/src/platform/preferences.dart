// BuildBeacon UI — Préférences de ce navigateur (langue choisie).
// Version 1.0 (2026-11-11)

import 'preferences_io.dart'
    if (dart.library.js_interop) 'preferences_web.dart'
    as platform;

/// Petites préférences propres à ce navigateur (localStorage) ; en mémoire
/// hors navigateur. Une lecture impossible (navigation privée, stockage
/// bloqué) donne `null` : l'interface marche quand même.
abstract interface class Preferences {
  factory Preferences() = platform.PlatformPreferences;

  String? read(String key);

  void write(String key, String? value);
}
