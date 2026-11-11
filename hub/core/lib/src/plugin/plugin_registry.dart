// BuildBeacon Hub — Registre des plugins de source disponibles.
// Version 1.2 (2026-11-11) — messages traduits ; erreurs de programmation en anglais.

import 'package:buildbeacon_plugin_sdk/buildbeacon_plugin_sdk.dart';

import '../model/source_config.dart';
import '../model/zone_action.dart';

/// Plugins disponibles, par type, et validation des sources qui les utilisent.
final class PluginRegistry {
  /// Lève une [ArgumentError] pour un plugin non conforme (voir
  /// `conformanceIssues`) ou deux plugins du même type.
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

  /// Problèmes d'une source : type inconnu, ou réglages refusés par le
  /// plugin (voir `settingsIssues`).
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

  /// Problèmes d'une action : ceux de sa source, puis la compatibilité du
  /// mode avec ce que fournit le plugin.
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
