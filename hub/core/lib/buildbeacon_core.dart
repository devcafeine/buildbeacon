// BuildBeacon Hub — API publique du cœur : modèle, rendu, registre des plugins.
// Version 1.4 (2026-11-11) — mire de mise en service (TestPattern).

/// Cœur de BuildBeacon : modèle de configuration, calcul de l'image des LED
/// et registre des plugins de source.
///
/// Pur Dart (pas de `dart:io`) : partagé par le serveur et l'interface. Il
/// réexporte le SDK des plugins ; un plugin, lui, n'importe que le SDK.
library;

export 'package:buildbeacon_plugin_sdk/buildbeacon_plugin_sdk.dart';

export 'src/model/config.dart';
export 'src/model/led_layout.dart';
export 'src/model/palette.dart';
export 'src/model/rgb.dart';
export 'src/model/source_config.dart';
export 'src/model/thresholds.dart';
export 'src/model/tile.dart';
export 'src/model/zone_action.dart';
export 'src/plugin/plugin_registry.dart';
export 'src/render/frame_renderer.dart';
export 'src/render/led_frame.dart';
export 'src/render/test_pattern.dart';
