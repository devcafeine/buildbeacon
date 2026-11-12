// BuildBeacon UI — What the Hub is showing right now ("state" event).
// Version 1.1 (2026-11-12) — comments in English.

import 'package:buildbeacon_core/buildbeacon_core.dart';

/// Connection to WLED, according to the Hub's last check.
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

  /// `null` before the first check.
  final DateTime? checkedAt;
  final String? version;
  final String? name;

  /// LED count set in WLED.
  final int? ledCount;

  /// Short reason ("Connection refused", "timeout") if the WLED JSON API
  /// is unreachable: expected with the simulator.
  final String? error;

  bool get reachable => ledCount != null;
}

/// Live state of the Hub: source states (to recompute the preview, even
/// for a configuration not saved yet), tiles being identified, WLED.
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

  /// Source states, by source key (`SourceConfig.key`).
  final Map<String, SourceState> sources;

  final Set<String> identifying;
  final WledLive wled;

  /// Does any LED of the preview need to move (pulse, blink)?
  bool get animated =>
      identifying.isNotEmpty ||
      sources.values.any(
        (s) => s.status.pulses || s.history.any((status) => status.pulses),
      );
}
