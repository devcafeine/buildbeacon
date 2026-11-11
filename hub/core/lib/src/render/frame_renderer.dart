// BuildBeacon Hub — Calcul de l'image des LED (config + état des sources + temps).
// Version 1.3 (2026-11-11) — identifiants en anglais (modes, états, types de tuile).

import 'dart:math';

import 'package:buildbeacon_plugin_sdk/buildbeacon_plugin_sdk.dart';

import '../model/config.dart';
import '../model/led_layout.dart';
import '../model/palette.dart';
import '../model/rgb.dart';
import '../model/tile.dart';
import '../model/zone_action.dart';
import 'led_frame.dart';

/// Ce que montre une LED : un état (donc une couleur) et une intensité
/// relative, de 0 (éteinte) à 1 (pleine couleur).
typedef LedOutput = ({Status status, double intensity});

/// Calcule l'image des LED.
///
/// Fonction pure du temps : la boucle de sortie l'appelle à chaque frame
/// (~20 images/s) avec le temps écoulé depuis le démarrage ; toutes les LED
/// qui pulsent sont ainsi synchrones.
final class FrameRenderer {
  const FrameRenderer({
    this.pulsePeriod = const Duration(seconds: 2),
    this.pulseFloor = 0.15,
    this.identifyPeriod = const Duration(milliseconds: 500),
  });

  /// Durée d'un cycle de pulsation (en cours / en file).
  final Duration pulsePeriod;

  /// Luminosité relative au creux de la pulsation (0 – 1).
  final double pulseFloor;

  /// Durée d'un cycle allumé/éteint du clignotement « identifier ».
  final Duration identifyPeriod;

  /// Image de toute la chaîne à l'instant [t].
  ///
  /// [states] est indexé par clé de source ; une source absente s'affiche
  /// « inconnu ». Les tuiles de [identify] (ids) clignotent en blanc à la place
  /// de leur affichage normal. Une tuile au rang invalide est ignorée
  /// (le signaler est le rôle de [Config.validate]).
  LedFrame render(
    Config config,
    Map<String, SourceState> states,
    Duration t, {
    Set<String> identify = const {},
  }) {
    final frame = LedFrame(config.ledCount);
    for (final tile in config.tiles) {
      if (tile.kind == TileKind.project && tile.chainIndex < 1) continue;

      if (identify.contains(tile.id)) {
        final color = _identifyOn(t) ? Rgb.white : Rgb.black;
        for (final i in LedLayout.tileIndices(tile.kind, tile.chainIndex)) {
          frame[i] = color;
        }
        continue;
      }

      for (final MapEntry(key: zone, value: action) in tile.zones.entries) {
        if (!tile.kind.zones.contains(zone)) continue;
        final indices = LedLayout.zoneIndices(tile.kind, tile.chainIndex, zone);
        final outputs = zoneOutputs(
          action,
          states[action.source.key] ?? SourceState.unknown,
          indices.length,
        );
        for (final (i, output) in outputs.indexed) {
          frame[indices[i]] = colorFor(config.palette, output, t);
        }
      }
    }
    return frame;
  }

  /// Ce que montre chaque LED d'une zone, dans l'ordre d'affichage.
  ///
  /// Indépendant du temps : sert aussi à l'aperçu de l'interface.
  static List<LedOutput> zoneOutputs(
    ZoneAction action,
    SourceState source,
    int ledCount,
  ) => switch (action.mode) {
    DisplayMode.overall => _uniform(source.status, ledCount),
    DisplayMode.history => [
      for (var i = 0; i < ledCount; i++)
        _full(i < source.history.length ? source.history[i] : Status.unknown),
    ],
    DisplayMode.thresholds => _uniform(
      _thresholdStatus(action, source),
      ledCount,
    ),
    DisplayMode.gauge => _gauge(action, source, ledCount),
  };

  /// Couleur d'une LED à l'instant [t] (intensité et pulsation comprises).
  Rgb colorFor(Palette palette, LedOutput led, Duration t) {
    if (led.intensity <= 0) return Rgb.black;
    final pulse = led.status.pulses ? pulseLevel(t) : 1.0;
    return palette[led.status].scaled(led.intensity * pulse);
  }

  /// Niveau de pulsation : [pulseFloor] à t = 0, maximum (1) à mi-période,
  /// variation en cosinus.
  double pulseLevel(Duration t) {
    final period = pulsePeriod.inMicroseconds;
    final phase = (t.inMicroseconds % period) / period;
    return pulseFloor + (1 - pulseFloor) * (1 - cos(2 * pi * phase)) / 2;
  }

  static LedOutput _full(Status status) => (status: status, intensity: 1.0);

  static List<LedOutput> _uniform(Status status, int ledCount) =>
      List.filled(ledCount, _full(status));

  static Status _thresholdStatus(ZoneAction action, SourceState source) {
    final metric = source.metric(action.metric);
    if (metric == null || action.thresholds.isEmpty) return Status.unknown;
    return action.thresholds.evaluate(metric.value);
  }

  /// Jauge de gauche à droite. La dernière LED allumée l'est en partie, pour
  /// que la progression avance en douceur : 62 % sur 5 LED = 3 pleines,
  /// la 4e à 10 %, la 5e éteinte.
  static List<LedOutput> _gauge(
    ZoneAction action,
    SourceState source,
    int ledCount,
  ) {
    final metric = source.metric(action.metric);
    final min = action.min ?? metric?.min ?? 0;
    final max = action.max ?? metric?.max ?? 100;
    if (metric == null || max <= min) return _uniform(Status.unknown, ledCount);

    final status = action.thresholds.isEmpty
        ? source.status
        : action.thresholds.evaluate(metric.value);
    final lit = ((metric.value - min) / (max - min)).clamp(0.0, 1.0) * ledCount;
    return [
      for (var i = 0; i < ledCount; i++)
        (status: status, intensity: (lit - i).clamp(0.0, 1.0).toDouble()),
    ];
  }

  bool _identifyOn(Duration t) {
    final period = identifyPeriod.inMicroseconds;
    return t.inMicroseconds % period < period ~/ 2;
  }
}
