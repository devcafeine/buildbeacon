// BuildBeacon Hub — Color associated with each status.
// Version 1.4 (2026-11-12) — comments in English.

import 'package:buildbeacon_plugin_sdk/buildbeacon_plugin_sdk.dart';

import 'rgb.dart';

/// Color of each [Status], configurable; statuses not provided get the
/// default color.
final class Palette {
  Palette([Map<Status, Rgb> overrides = const {}])
    : _colors = Map.unmodifiable({...defaults, ...overrides});

  /// Reads `{"success": "#00FF00", …}`. Unknown keys are ignored (config
  /// written by a newer version of the Hub).
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

  /// Default colors, deliberately saturated: the global brightness is set
  /// in WLED (50 % by default).
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
