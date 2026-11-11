// BuildBeacon Hub — Source d'une zone : un type de plugin et ses réglages.
// Version 1.0 (2026-11-11) — remplace la classe scellée Source (source.dart) :
// les types de source sont désormais fournis par des plugins.

import 'dart:convert';

import 'json_read.dart';

/// Source d'une zone : le [type] du plugin qui la lit et ses [settings].
///
/// En JSON, les réglages sont à plat à côté du type :
/// `{"type": "github", "repo": "acme/app", "workflow": "ci.yml"}`.
/// Le cœur ne les interprète pas : c'est le rôle du plugin (voir
/// `PluginRegistry.validateSource`).
final class SourceConfig {
  SourceConfig({required String type, Map<String, Object?> settings = const {}})
    : type = type.trim(),
      settings = Map.unmodifiable(_clean(settings));

  factory SourceConfig.fromJson(Map<String, Object?> json) => SourceConfig(
    type: json.field<String>('type'),
    settings: {
      for (final MapEntry(:key, :value) in json.entries)
        if (key != 'type') key: value,
    },
  );

  final String type;

  /// Réglages nettoyés : textes sans espaces autour, valeurs vides retirées.
  final Map<String, Object?> settings;

  /// Clé de regroupement : les zones dont la source a la même clé partagent
  /// une seule connexion au plugin et un seul état en cache.
  late final String key = '$type:${jsonEncode(_sortedKeys(settings))}';

  Map<String, Object?> toJson() => {'type': type, ...settings};

  static Map<String, Object?> _clean(Map<String, Object?> settings) => {
    for (final MapEntry(:key, :value) in settings.entries)
      key: ?_cleanValue(value),
  };

  static Object? _cleanValue(Object? value) => switch (value) {
    final String text when text.trim().isEmpty => null,
    final String text => text.trim(),
    _ => value,
  };

  static Map<String, Object?> _sortedKeys(Map<String, Object?> map) => {
    for (final key in map.keys.toList()..sort()) key: map[key],
  };
}
