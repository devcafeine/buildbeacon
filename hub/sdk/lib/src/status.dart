// BuildBeacon Hub — Plugin SDK: status shown by a zone or an LED.
// Version 1.4 (2026-11-12) — comments in English.

import 'localized_text.dart';

/// Display status, independent of the source: CI run, 3D printer, numeric
/// indicator compared with thresholds…
///
/// [json] is also the key in the `config.json` palette.
enum Status {
  success('success', LocalizedText({'en': 'success', 'fr': 'succès'})),

  /// Worth watching without being a failure: warning threshold crossed,
  /// print paused…
  warning('warning', LocalizedText({'en': 'warning', 'fr': 'attention'})),
  failure('failure', LocalizedText({'en': 'failure', 'fr': 'échec'})),
  running('running', LocalizedText({'en': 'running', 'fr': 'en cours'})),
  queued('queued', LocalizedText({'en': 'queued', 'fr': 'en file'})),
  cancelled('cancelled', LocalizedText({'en': 'cancelled', 'fr': 'annulé'})),
  unknown('unknown', LocalizedText({'en': 'unknown', 'fr': 'inconnu'}));

  const Status(this.json, this.label);

  final String json;

  /// Name shown in the interface.
  final LocalizedText label;

  /// "Live" statuses (running, queued) pulse when displayed.
  bool get pulses => this == running || this == queued;

  static Status? tryParse(String json) {
    for (final status in values) {
      if (status.json == json) return status;
    }
    return null;
  }
}
