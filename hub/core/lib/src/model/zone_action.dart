// BuildBeacon Hub — Action d'une zone : une source + un mode d'affichage.
// Version 1.3 (2026-11-11) — modes en anglais (overall, history, thresholds, gauge), libellés et messages traduits.

import 'package:buildbeacon_plugin_sdk/buildbeacon_plugin_sdk.dart';

import 'json_read.dart';
import 'source_config.dart';
import 'thresholds.dart';

/// Façon de traduire l'état d'une source en couleurs de LED.
enum DisplayMode {
  /// Toutes les LED prennent la couleur de l'état actuel de la source.
  overall(
    'overall',
    LocalizedText({'en': 'overall status', 'fr': 'état global'}),
  ),

  /// Une LED par élément de l'historique, le plus récent à gauche (point n° 1).
  history('history', LocalizedText({'en': 'history', 'fr': 'historique'})),

  /// Toutes les LED prennent la couleur d'une mesure comparée aux seuils.
  thresholds('thresholds', LocalizedText({'en': 'thresholds', 'fr': 'seuils'})),

  /// Barre de progression de gauche à droite selon une mesure.
  gauge('gauge', LocalizedText({'en': 'gauge', 'fr': 'jauge'}));

  const DisplayMode(this.json, this.label);

  final String json;

  /// Nom affiché dans l'interface.
  final LocalizedText label;

  static DisplayMode? tryParse(String json) {
    for (final mode in values) {
      if (mode.json == json) return mode;
    }
    return null;
  }
}

/// Action d'une zone. En JSON, les réglages propres au mode sont regroupés
/// sous `options` :
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

  /// Mesure lue par les modes thresholds et gauge ; `null` = la première
  /// mesure fournie par la source.
  final String? metric;

  /// Couleur selon la valeur : obligatoire en mode thresholds ; en mode
  /// gauge, remplace la couleur de l'état de la source s'ils sont définis.
  final Thresholds thresholds;

  /// Bornes de la jauge ; `null` = bornes données par la source, à défaut 0 – 100.
  final num? min;
  final num? max;

  /// Problèmes de réglage, traduits.
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
