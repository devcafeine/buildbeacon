// BuildBeacon Hub — Plugins livrés avec le Hub.
// Version 1.2 (2026-11-11) — repères en anglais pour `mise run new-plugin`.

import 'package:buildbeacon_core/buildbeacon_core.dart';
import 'package:buildbeacon_plugin_github/buildbeacon_plugin_github.dart';

// new-plugin: imports are added above this line.

/// Plugins compilés dans l'image du Hub.
///
/// Ajouter un plugin : `mise run new-plugin <name>` crée son paquet et
/// l'inscrit ici. À la main : dépendance dans `server/pubspec.yaml` et ligne
/// dans cette liste.
PluginRegistry builtinPlugins() => PluginRegistry(const [
  GithubPlugin(),
  // new-plugin: plugins are added above this line.
]);
