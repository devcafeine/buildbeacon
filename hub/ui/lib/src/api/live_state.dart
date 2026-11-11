// BuildBeacon UI — Ce que montre le Hub en ce moment (événement « state »).
// Version 1.0 (2026-11-11)

import 'package:buildbeacon_core/buildbeacon_core.dart';

/// Connexion à WLED, d'après la dernière vérification du Hub.
final class WledLive {
  const WledLive({
    this.checkedAt,
    this.version,
    this.name,
    this.ledCount,
    this.error,
  });

  factory WledLive.fromJson(Map<String, Object?> json) {
    final info = json['info'];
    final checkedAt = json['checked_at'];
    return WledLive(
      checkedAt: checkedAt is String ? DateTime.tryParse(checkedAt) : null,
      version: info is Map<String, Object?> ? info['version'] as String? : null,
      name: info is Map<String, Object?> ? info['name'] as String? : null,
      ledCount: info is Map<String, Object?> ? info['led_count'] as int? : null,
      error: json['error'] as String?,
    );
  }

  /// `null` avant la première vérification.
  final DateTime? checkedAt;
  final String? version;
  final String? name;

  /// Nombre de LED réglé dans WLED.
  final int? ledCount;

  /// Raison courte (« Connection refused », « timeout ») si l'API JSON de
  /// WLED est injoignable : normal avec le simulateur.
  final String? error;

  bool get reachable => ledCount != null;
}

/// État en direct du Hub : états des sources (pour recalculer l'aperçu,
/// même d'une configuration pas encore enregistrée), tuiles en train
/// d'être identifiées, WLED.
final class LiveState {
  const LiveState({
    this.sources = const {},
    this.identifying = const {},
    this.wled = const WledLive(),
  });

  factory LiveState.fromJson(Map<String, Object?> json) {
    final sources = <String, SourceState>{};
    if (json['sources'] case final Map<String, Object?> map) {
      for (final MapEntry(:key, :value) in map.entries) {
        if (value is Map<String, Object?>) {
          sources[key] = SourceStateJson.decode(value);
        }
      }
    }
    return LiveState(
      sources: sources,
      identifying: {
        if (json['tiles'] case final List<Object?> tiles)
          for (final tile in tiles)
            if (tile case {'id': final String id, 'identifying': true}) id,
      },
      wled: json['wled'] is Map<String, Object?>
          ? WledLive.fromJson(json['wled']! as Map<String, Object?>)
          : const WledLive(),
    );
  }

  static const empty = LiveState();

  /// États des sources, par clé de source (`SourceConfig.key`).
  final Map<String, SourceState> sources;

  final Set<String> identifying;
  final WledLive wled;

  /// Une LED de l'aperçu doit-elle bouger (pulsation, clignotement) ?
  bool get animated =>
      identifying.isNotEmpty ||
      sources.values.any(
        (s) => s.status.pulses || s.history.any((status) => status.pulses),
      );
}
