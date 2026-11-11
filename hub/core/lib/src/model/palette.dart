// BuildBeacon Hub — Couleur associée à chaque état.
// Version 1.3 (2026-11-11) — clés en anglais (success, failure…), erreur traduite.

import 'package:buildbeacon_plugin_sdk/buildbeacon_plugin_sdk.dart';

import 'rgb.dart';

/// Couleur de chaque [Status], réglable ; les états non fournis prennent
/// la couleur par défaut.
final class Palette {
  Palette([Map<Status, Rgb> overrides = const {}])
    : _colors = Map.unmodifiable({...defaults, ...overrides});

  /// Lit `{"success": "#00FF00", …}`. Les clés inconnues sont ignorées
  /// (config écrite par une version plus récente du Hub).
  factory Palette.fromJson(Map<String, Object?> json) {
    final overrides = <Status, Rgb>{};
    for (final MapEntry(:key, :value) in json.entries) {
      final status = Status.tryParse(key);
      if (status == null) continue;
      if (value is! String) {
        throw LocalizedFormatException(
          LocalizedText.build(
            (l) => tr(
              l,
              en: 'Palette: invalid color for "$key"',
              fr: 'Palette : couleur invalide pour « $key »',
            ),
          ),
        );
      }
      overrides[status] = Rgb.parse(value);
    }
    return Palette(overrides);
  }

  /// Couleurs par défaut, choisies saturées : la luminosité globale est
  /// réglée dans WLED (50 % par défaut).
  static const defaults = <Status, Rgb>{
    Status.success: Rgb(0, 255, 0),
    Status.warning: Rgb(255, 170, 0),
    Status.failure: Rgb(255, 0, 0),
    Status.running: Rgb(255, 80, 0),
    Status.queued: Rgb(255, 80, 0),
    Status.cancelled: Rgb(0, 64, 255),
    Status.unknown: Rgb(32, 32, 32),
  };

  final Map<Status, Rgb> _colors;

  Rgb operator [](Status status) => _colors[status]!;

  Map<String, Object?> toJson() => {
    for (final status in Status.values) status.json: this[status].toHex(),
  };
}
