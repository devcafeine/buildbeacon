// BuildBeacon Hub — Plugin SDK: public API.
// Version 1.2 (2026-11-12) — comments in English.

/// SDK for BuildBeacon source plugins.
///
/// A plugin imports only this library (plus `testing.dart` in its tests).
/// Everything it exports follows the SDK versioning: the Hub core can evolve
/// without breaking plugins.
library;

export 'src/localized_text.dart';
export 'src/plugin_schema.dart';
export 'src/polling.dart';
export 'src/source_plugin.dart';
export 'src/source_settings.dart';
export 'src/source_state.dart';
export 'src/status.dart';
export 'src/validation.dart';
