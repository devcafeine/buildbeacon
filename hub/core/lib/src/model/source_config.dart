// BuildBeacon Hub — Source of a zone: a plugin type and its settings.
// Version 1.1 (2026-11-12) — comments in English.

import 'dart:convert';

import 'json_read.dart';

/// Source of a zone: the [type] of the plugin that reads it and its [settings].
///
/// In JSON, the settings sit flat next to the type:
/// `{"type": "github", "repo": "acme/app", "workflow": "ci.yml"}`.
/// The core does not interpret them: that is the plugin's job (see
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

  /// Cleaned settings: texts trimmed, empty values removed.
  final Map<String, Object?> settings;

  /// Grouping key: zones whose source has the same key share a single
  /// connection to the plugin and a single cached state.
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
