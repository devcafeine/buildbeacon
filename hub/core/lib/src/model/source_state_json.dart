// BuildBeacon Hub — Source state ↔ JSON (Hub API, UI preview).
// Version 1.1 (2026-11-12) — comments in English.

import 'package:buildbeacon_plugin_sdk/buildbeacon_plugin_sdk.dart';

/// JSON conversion of [SourceState], shared by the server (which sends it)
/// and the UI (which recomputes the LED preview from these states).
///
/// Format:
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

  /// Lenient reading: an unknown status becomes `unknown` and an unknown
  /// metric is ignored (Hub newer than the UI).
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
