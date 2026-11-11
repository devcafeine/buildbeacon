// BuildBeacon Hub — SDK des plugins : API publique.
// Version 1.1 (2026-11-11) — textes traduits (localized_text.dart).

/// SDK des plugins de source BuildBeacon.
///
/// Un plugin n'importe que cette bibliothèque (et `testing.dart` dans ses
/// tests). Tout ce qu'elle exporte suit le versionnage du SDK : le cœur du
/// Hub peut évoluer sans casser les plugins.
library;

export 'src/localized_text.dart';
export 'src/plugin_schema.dart';
export 'src/polling.dart';
export 'src/source_plugin.dart';
export 'src/source_settings.dart';
export 'src/source_state.dart';
export 'src/status.dart';
export 'src/validation.dart';
