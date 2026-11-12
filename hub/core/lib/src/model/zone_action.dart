// BuildBeacon Hub — Action of a zone: a source + a display mode.
// Version 1.4 (2026-11-12) — comments in English.

import 'package:buildbeacon_plugin_sdk/buildbeacon_plugin_sdk.dart';

import 'json_read.dart';
import 'source_config.dart';
import 'thresholds.dart';

/// How the state of a source is turned into LED colors.
enum DisplayMode {
  /// All LEDs take the color of the source's current status.
  overall(
    'overall',
    LocalizedText({'en': 'overall status', 'fr': 'état global'}),
  ),

  /// One LED per history entry, the most recent on the left (dot #1).
  history('history', LocalizedText({'en': 'history', 'fr': 'historique'})),

  /// All LEDs take the color of a measurement compared with the thresholds.
  thresholds('thresholds', LocalizedText({'en': 'thresholds', 'fr': 'seuils'})),

  /// Progress bar from left to right, driven by a measurement.
  gauge('gauge', LocalizedText({'en': 'gauge', 'fr': 'jauge'}));

  const DisplayMode(this.json, this.label);

  final String json;

  /// Name shown in the UI.
  final LocalizedText label;

  static DisplayMode? tryParse(String json) {
    for (final mode in values) {
      if (mode.json == json) return mode;
    }
    return null;
  }
}

/// Action of a zone. In JSON, the mode-specific settings are grouped under
/// `options`:
/// `{"metric": "progress", "thresholds": {…}, "min": 0, "max": 100}`.
final class ZoneAction {
  const ZoneAction({
    required this.source,
    required this.mode,
    this.metric,
    this.thresholds = Thresholds.none,
    this.min,
    this.max,
  });

  factory ZoneAction.fromJson(Map<String, Object?> json) {
    final modeName = json.field<String>('mode');
    final options = json.objectField('options');
    return ZoneAction(
      source: SourceConfig.fromJson(json.field<Map<String, Object?>>('source')),
      mode:
          DisplayMode.tryParse(modeName) ??
          (throw LocalizedFormatException(
            LocalizedText.build(
              (l) => tr(
                l,
                en: 'Unknown display mode: $modeName',
                fr: 'Mode d\'affichage inconnu : $modeName',
              ),
            ),
          )),
      metric: options.optionalField<String>('metric'),
      thresholds: Thresholds.fromJson(options.objectField('thresholds')),
      min: options.optionalField<num>('min'),
      max: options.optionalField<num>('max'),
    );
  }

  final SourceConfig source;
  final DisplayMode mode;

  /// Measurement read by the thresholds and gauge modes; `null` = the first
  /// measurement provided by the source.
  final String? metric;

  /// Color according to the value: required in thresholds mode; in gauge
  /// mode, replaces the color of the source's status when defined.
  final Thresholds thresholds;

  /// Gauge bounds; `null` = bounds given by the source, otherwise 0 – 100.
  final num? min;
  final num? max;

  /// Settings problems, translated.
  List<LocalizedText> validate() {
    final (low, high) = (min, max);
    return [
      ...thresholds.validate(),
      if (mode == DisplayMode.thresholds && thresholds.isEmpty)
        const LocalizedText({
          'en':
              'the thresholds mode needs at least one threshold '
              '(warning or failure)',
          'fr':
              'le mode seuils demande au moins un seuil '
              '(warning ou failure)',
        }),
      if (low != null && high != null && high <= low)
        LocalizedText.build(
          (l) => tr(
            l,
            en: 'gauge: max ($high) must be greater than min ($low)',
            fr: 'jauge : max ($high) doit être supérieur à min ($low)',
          ),
        ),
    ];
  }

  Map<String, Object?> toJson() => {
    'source': source.toJson(),
    'mode': mode.json,
    'options': {
      if (metric != null) 'metric': metric,
      if (!thresholds.isEmpty) 'thresholds': thresholds.toJson(),
      if (min != null) 'min': min,
      if (max != null) 'max': max,
    },
  };
}
