// BuildBeacon Hub — SDK des plugins : dernier état connu d'une source.
// Version 1.4 (2026-11-11) — erreur traduite (LocalizedText), identifiants de mesure en anglais.

import 'localized_text.dart';
import 'status.dart';

/// Valeur chiffrée fournie par une source : progression d'une impression,
/// température, compteur du jour…
final class Metric {
  const Metric(this.value, {this.unit, this.min, this.max});

  final double value;

  /// Unité, pour l'aperçu (`%`, `°C`, `min`…).
  final String? unit;

  /// Bornes naturelles de la mesure (0 – 100 pour un pourcentage), utilisées
  /// par la jauge quand l'action n'en fixe pas.
  final double? min;
  final double? max;
}

/// Dernier état connu d'une source, partagé par toutes les zones de même clé.
///
/// Chaque source remplit ce qu'elle sait fournir :
/// - GitHub : [history], les runs du plus récent au plus ancien ;
/// - imprimante 3D : [status] (en cours, en pause…) et des [metrics]
///   (`progress`, `remaining_time`, `nozzle_temp`…) ;
/// - indicateur seul : des [metrics], et [status] succès quand la lecture
///   a réussi (couleur de la jauge sans seuils).
final class SourceState {
  const SourceState({
    Status? status,
    this.history = const [],
    this.metrics = const {},
    this.error,
    this.updatedAt,
  }) : _status = status;

  /// Source jamais lue : tout s'affiche « inconnu ».
  static const unknown = SourceState();

  final Status? _status;

  /// Historique, du plus récent au plus ancien.
  final List<Status> history;

  /// Mesures chiffrées, par identifiant propre à la source.
  final Map<String, Metric> metrics;

  /// Dernière erreur de lecture (réseau, droits, appareil injoignable…),
  /// affichée dans l'interface ; les valeurs précédentes restent affichées.
  final LocalizedText? error;

  final DateTime? updatedAt;

  /// État actuel : celui fourni par la source, sinon le plus récent de
  /// l'historique, sinon inconnu.
  Status get status => _status ?? history.firstOrNull ?? Status.unknown;

  /// Mesure [id] ; sans [id], la première fournie par la source.
  Metric? metric([String? id]) =>
      id == null ? metrics.values.firstOrNull : metrics[id];

  /// Même état avec une erreur de lecture, ou sans erreur si [error] est nul.
  SourceState withError(LocalizedText? error) => SourceState(
    status: _status,
    history: history,
    metrics: metrics,
    error: error,
    updatedAt: updatedAt,
  );
}
