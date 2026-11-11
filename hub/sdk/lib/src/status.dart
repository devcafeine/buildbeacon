// BuildBeacon Hub — SDK des plugins : état affiché par une zone ou une LED.
// Version 1.3 (2026-11-11) — identifiants en anglais (success, failure…), libellés traduits.

import 'localized_text.dart';

/// État d'affichage, indépendant de la source : run de CI, imprimante 3D,
/// indicateur chiffré comparé à des seuils…
///
/// [json] sert aussi de clé dans la palette de `config.json`.
enum Status {
  success('success', LocalizedText({'en': 'success', 'fr': 'succès'})),

  /// À surveiller sans être un échec : seuil d'attention franchi,
  /// impression en pause…
  warning('warning', LocalizedText({'en': 'warning', 'fr': 'attention'})),
  failure('failure', LocalizedText({'en': 'failure', 'fr': 'échec'})),
  running('running', LocalizedText({'en': 'running', 'fr': 'en cours'})),
  queued('queued', LocalizedText({'en': 'queued', 'fr': 'en file'})),
  cancelled('cancelled', LocalizedText({'en': 'cancelled', 'fr': 'annulé'})),
  unknown('unknown', LocalizedText({'en': 'unknown', 'fr': 'inconnu'}));

  const Status(this.json, this.label);

  final String json;

  /// Nom affiché dans l'interface.
  final LocalizedText label;

  /// Les états « vivants » (en cours, en file) pulsent à l'affichage.
  bool get pulses => this == running || this == queued;

  static Status? tryParse(String json) {
    for (final status in values) {
      if (status.json == json) return status;
    }
    return null;
  }
}
