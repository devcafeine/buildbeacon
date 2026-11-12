// BuildBeacon Hub — Registry of the available source plugins.
// Version 1.3 (2026-11-12) — comments in English.

import 'package:buildbeacon_plugin_sdk/buildbeacon_plugin_sdk.dart';

import '../model/source_config.dart';
import '../model/zone_action.dart';

/// Available plugins, by type, and validation of the sources that use them.
final class PluginRegistry {
  /// Throws an [ArgumentError] for a non-conforming plugin (see
  /// `conformanceIssues`) or for two plugins of the same type.
  PluginRegistry(Iterable<SourcePlugin> plugins) {
    for (final plugin in plugins) {
      final issues = conformanceIssues(plugin);
      if (issues.isNotEmpty) {
        throw ArgumentError(
          'Plugin "${plugin.type}" does not conform: ${issues.join('; ')}',
        );
      }
      if (_plugins.containsKey(plugin.type)) {
        throw ArgumentError('Two plugins of type "${plugin.type}"');
      }
      _plugins[plugin.type] = plugin;
    }
  }

  final _plugins = <String, SourcePlugin>{};

  SourcePlugin? operator [](String type) => _plugins[type];

  List<SourcePlugin> get all => List.unmodifiable(_plugins.values);

  /// Problems of a source: unknown type, or settings rejected by the plugin
  /// (see `settingsIssues`).
  List<LocalizedText> validateSource(SourceConfig source) {
    final plugin = _plugins[source.type];
    if (plugin == null) {
      final available = _plugins.keys.join(', ');
      return [
        LocalizedText.build(
          (l) => tr(
            l,
            en: 'unknown source type "${source.type}" (available: $available)',
            fr:
                'source de type inconnu « ${source.type} » '
                '(disponibles : $available)',
          ),
        ),
      ];
    }
    return settingsIssues(plugin, source.settings);
  }

  /// Problems of an action: those of its source, then whether the mode is
  /// compatible with what the plugin provides.
  List<LocalizedText> validateAction(ZoneAction action) {
    final plugin = _plugins[action.source.type];
    if (plugin == null) return validateSource(action.source);

    final mode = action.mode;
    final needsMetric =
        mode == DisplayMode.thresholds || mode == DisplayMode.gauge;
    final metricIds = {for (final m in plugin.metrics) m.id};
    final metric = action.metric;
    return [
      ...validateSource(action.source),
      if (mode == DisplayMode.history && !plugin.providesHistory)
        LocalizedText.build(
          (l) => tr(
            l,
            en:
                '${plugin.label.resolve(l)} provides no history: '
                '"${mode.label.resolve(l)}" mode unavailable',
            fr:
                '${plugin.label.resolve(l)} ne fournit pas d\'historique : '
                'mode « ${mode.label.resolve(l)} » impossible',
          ),
        ),
      if (needsMetric && metricIds.isEmpty && !plugin.dynamicMetrics)
        LocalizedText.build(
          (l) => tr(
            l,
            en:
                '${plugin.label.resolve(l)} provides no measurement: '
                '"${mode.label.resolve(l)}" mode unavailable',
            fr:
                '${plugin.label.resolve(l)} ne fournit pas de mesure : '
                'mode « ${mode.label.resolve(l)} » impossible',
          ),
        ),
      if (needsMetric &&
          metric != null &&
          metricIds.isNotEmpty &&
          !plugin.dynamicMetrics &&
          !metricIds.contains(metric))
        LocalizedText.build(
          (l) => tr(
            l,
            en:
                'unknown measurement "$metric" for '
                '${plugin.label.resolve(l)} (${metricIds.join(', ')})',
            fr:
                'mesure « $metric » inconnue pour '
                '${plugin.label.resolve(l)} (${metricIds.join(', ')})',
          ),
        ),
    ];
  }
}
