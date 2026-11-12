// BuildBeacon UI — Description of a source plugin, received from /api/plugins.
// Version 1.1 (2026-11-12) — comments in English.

import 'package:buildbeacon_core/buildbeacon_core.dart';

import 'json_text.dart';

/// A plugin secret: the API only tells whether it is set on the Hub.
final class SecretInfo {
  const SecretInfo({
    required this.env,
    required this.label,
    required this.required,
    required this.configured,
    this.help,
  });

  final String env;
  final LocalizedText label;
  final bool required;
  final bool configured;
  final LocalizedText? help;
}

/// What the interface knows about a plugin: enough to generate the source
/// form and offer the display modes it can feed.
final class PluginInfo {
  const PluginInfo({
    required this.type,
    required this.label,
    this.description = const LocalizedText.same(''),
    this.settings = const [],
    this.secrets = const [],
    this.providesHistory = false,
    this.metrics = const [],
    this.dynamicMetrics = false,
  });

  factory PluginInfo.fromJson(Map<String, Object?> json) {
    List<Map<String, Object?>> objects(String key) => [
      if (json[key] case final List<Object?> list)
        for (final item in list)
          if (item is Map<String, Object?>) item,
    ];
    double? number(Object? value) => value is num ? value.toDouble() : null;
    String? text(Object? value) => value is String ? value : null;

    return PluginInfo(
      type: json['type'] as String? ?? '',
      label: localizedFromJson(json['label']),
      description: localizedFromJson(json['description']),
      settings: [
        for (final s in objects('settings'))
          SettingField(
            id: s['id'] as String? ?? '',
            label: localizedFromJson(s['label']),
            kind: SettingKind.values.asNameMap()[s['kind']] ?? SettingKind.text,
            required: s['required'] == true,
            help: optionalLocalized(s['help']),
            placeholder: text(s['placeholder']),
            pattern: text(s['pattern']),
            patternHint: optionalLocalized(s['pattern_hint']),
            choices: [
              if (s['choices'] case final List<Object?> choices)
                for (final choice in choices)
                  if (choice is String) choice,
            ],
          ),
      ],
      secrets: [
        for (final s in objects('secrets'))
          SecretInfo(
            env: s['env'] as String? ?? '',
            label: localizedFromJson(s['label']),
            required: s['required'] == true,
            configured: s['configured'] == true,
            help: optionalLocalized(s['help']),
          ),
      ],
      providesHistory: json['provides_history'] == true,
      metrics: [
        for (final m in objects('metrics'))
          MetricInfo(
            id: m['id'] as String? ?? '',
            label: localizedFromJson(m['label']),
            unit: text(m['unit']),
            min: number(m['min']),
            max: number(m['max']),
          ),
      ],
      dynamicMetrics: json['dynamic_metrics'] == true,
    );
  }

  final String type;
  final LocalizedText label;
  final LocalizedText description;
  final List<SettingField> settings;
  final List<SecretInfo> secrets;
  final bool providesHistory;
  final List<MetricInfo> metrics;
  final bool dynamicMetrics;

  /// Can the plugin feed [mode]?
  bool supports(DisplayMode mode) => switch (mode) {
    DisplayMode.overall => true,
    DisplayMode.history => providesHistory,
    DisplayMode.thresholds ||
    DisplayMode.gauge => metrics.isNotEmpty || dynamicMetrics,
  };
}
