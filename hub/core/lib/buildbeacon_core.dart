// BuildBeacon Hub — Public API of the core: model, rendering, plugin registry.
// Version 1.6 (2026-11-12) — comments in English.

/// BuildBeacon core: configuration model, LED frame computation and source
/// plugin registry.
///
/// Pure Dart (no `dart:io`): shared by the server and the UI. It re-exports
/// the plugin SDK; a plugin, on the other hand, imports only the SDK.
library;

export 'package:buildbeacon_plugin_sdk/buildbeacon_plugin_sdk.dart';

export 'src/model/config.dart';
export 'src/model/led_layout.dart';
export 'src/model/palette.dart';
export 'src/model/rgb.dart';
export 'src/model/source_config.dart';
export 'src/model/source_state_json.dart';
export 'src/model/thresholds.dart';
export 'src/model/tile.dart';
export 'src/model/zone_action.dart';
export 'src/plugin/plugin_registry.dart';
export 'src/render/frame_renderer.dart';
export 'src/render/led_frame.dart';
export 'src/render/test_pattern.dart';
