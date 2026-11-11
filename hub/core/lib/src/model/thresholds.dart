// BuildBeacon Hub — Seuils d'alerte d'un indicateur chiffré.
// Version 1.2 (2026-11-11) — identifiants en anglais (warning, failure, above, below), messages traduits.

import 'package:buildbeacon_plugin_sdk/buildbeacon_plugin_sdk.dart';

import 'json_read.dart';

/// Sens dans lequel une valeur devient inquiétante.
enum AlertDirection {
  /// Température, taux d'erreur, file d'attente… : trop haut = problème.
  above('above', LocalizedText({'en': 'above', 'fr': 'au-dessus'})),

  /// Filament restant, ventes du jour… : trop bas = problème.
  below('below', LocalizedText({'en': 'below', 'fr': 'en dessous'}));

  const AlertDirection(this.json, this.label);

  final String json;
  final LocalizedText label;

  static AlertDirection? tryParse(String json) {
    for (final direction in values) {
      if (direction.json == json) return direction;
    }
    return null;
  }
}

/// Seuils d'un indicateur. Avant le seuil [warning] : succès ; à partir de
/// [warning] : attention ; à partir de [failure] : échec. Chaque seuil est
/// facultatif ; [direction] dit si l'on alerte au-dessus ou en dessous.
final class Thresholds {
  const Thresholds({
    this.warning,
    this.failure,
    this.direction = AlertDirection.above,
  });

  /// Lit `{"warning": 240, "failure": 260, "direction": "above"}`.
  factory Thresholds.fromJson(Map<String, Object?> json) {
    final direction = json.optionalField<String>('direction');
    return Thresholds(
      warning: json.optionalField<num>('warning'),
      failure: json.optionalField<num>('failure'),
      direction: direction == null
          ? AlertDirection.above
          : AlertDirection.tryParse(direction) ??
                (throw LocalizedFormatException(
                  LocalizedText.build(
                    (l) => tr(
                      l,
                      en:
                          'Unknown threshold direction: $direction '
                          '(above or below)',
                      fr:
                          'Direction de seuil inconnue : $direction '
                          '(above ou below)',
                    ),
                  ),
                )),
    );
  }

  static const none = Thresholds();

  final num? warning;
  final num? failure;
  final AlertDirection direction;

  bool get isEmpty => warning == null && failure == null;

  /// État correspondant à [value].
  Status evaluate(num value) {
    bool reached(num? threshold) =>
        threshold != null &&
        switch (direction) {
          AlertDirection.above => value >= threshold,
          AlertDirection.below => value <= threshold,
        };

    if (reached(failure)) return Status.failure;
    if (reached(warning)) return Status.warning;
    return Status.success;
  }

  List<LocalizedText> validate() {
    final (w, f) = (warning, failure);
    if (w == null || f == null) return const [];
    final wrongOrder = switch (direction) {
      AlertDirection.above => w > f,
      AlertDirection.below => w < f,
    };
    if (!wrongOrder) return const [];
    final above = direction == AlertDirection.above;
    return [
      LocalizedText.build(
        (l) => tr(
          l,
          en:
              'warning threshold ($w) ${above ? 'above' : 'below'} the '
              'failure threshold ($f) while alerting '
              '${direction.label.resolve(l)}',
          fr:
              'seuil d\'attention ($w) ${above ? 'au-dessus' : 'en dessous'} '
              'du seuil d\'échec ($f) alors que l\'alerte est '
              '« ${direction.label.resolve(l)} »',
        ),
      ),
    ];
  }

  Map<String, Object?> toJson() => {
    if (warning != null) 'warning': warning,
    if (failure != null) 'failure': failure,
    'direction': direction.json,
  };
}
