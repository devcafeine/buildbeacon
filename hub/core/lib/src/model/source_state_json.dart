// BuildBeacon Hub — État d'une source ↔ JSON (API du Hub, aperçu de l'interface).
// Version 1.0 (2026-11-11)

import 'package:buildbeacon_plugin_sdk/buildbeacon_plugin_sdk.dart';

/// Conversion JSON de [SourceState], partagée par le serveur (qui l'envoie)
/// et l'interface (qui recalcule l'aperçu des LED à partir de ces états).
///
/// Format :
/// `{"status": "success", "history": ["success", …], "metrics": {"progress":
/// {"value": 42.0, "unit": "%", "min": 0.0, "max": 100.0}}, "error": {"en":
/// "…", "fr": "…"} | null, "updated_at": "2026-11-11T21:55:46Z" | null}`.
abstract final class SourceStateJson {
  static Map<String, Object?> encode(SourceState state) => {
    'status': state.status.json,
    'history': [for (final status in state.history) status.json],
    'metrics': {
      for (final MapEntry(key: id, value: metric) in state.metrics.entries)
        id: {
          'value': metric.value,
          'unit': ?metric.unit,
          'min': ?metric.min,
          'max': ?metric.max,
        },
    },
    'error': state.error?.toJson(),
    'updated_at': state.updatedAt?.toUtc().toIso8601String(),
  };

  /// Lecture tolérante : un état ou une mesure inconnus deviennent
  /// « inconnu » ou sont ignorés (Hub plus récent que l'interface).
  static SourceState decode(Map<String, Object?> json) {
    Status status(Object? name) => name is String
        ? Status.tryParse(name) ?? Status.unknown
        : Status.unknown;
    double? number(Object? value) => value is num ? value.toDouble() : null;

    final history = switch (json['history']) {
      final List<Object?> list => list,
      _ => const <Object?>[],
    };
    final metrics = <String, Metric>{};
    final metricsJson = switch (json['metrics']) {
      final Map<String, Object?> map => map,
      _ => const <String, Object?>{},
    };
    for (final MapEntry(:key, :value) in metricsJson.entries) {
      if (value is! Map<String, Object?>) continue;
      final metricValue = number(value['value']);
      if (metricValue == null) continue;
      metrics[key] = Metric(
        metricValue,
        unit: value['unit'] is String ? value['unit']! as String : null,
        min: number(value['min']),
        max: number(value['max']),
      );
    }
    final error = json['error'];
    final updatedAt = json['updated_at'];
    return SourceState(
      status: status(json['status']),
      history: [for (final name in history) status(name)],
      metrics: metrics,
      error: error is Map<String, Object?>
          ? LocalizedText({
              for (final MapEntry(:key, :value) in error.entries)
                if (value is String) key: value,
            })
          : null,
      updatedAt: updatedAt is String ? DateTime.tryParse(updatedAt) : null,
    );
  }
}
