// BuildBeacon Hub — Plugins shipped with the Hub.
// Version 1.3 (2026-11-12) — comments in English.

import 'package:buildbeacon_core/buildbeacon_core.dart';
import 'package:buildbeacon_plugin_github/buildbeacon_plugin_github.dart';

// new-plugin: imports are added above this line.

/// Plugins compiled into the Hub image.
///
/// Adding a plugin: `mise run new-plugin <name>` creates its package and
/// registers it here. By hand: a dependency in `server/pubspec.yaml` and a
/// line in this list.
PluginRegistry builtinPlugins() => PluginRegistry(const [
  GithubPlugin(),
  // new-plugin: plugins are added above this line.
]);
