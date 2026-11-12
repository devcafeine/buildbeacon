// BuildBeacon Hub — LED frame computation (config + source states + time).
// Version 1.4 (2026-11-12) — comments in English.

import 'dart:math';

import 'package:buildbeacon_plugin_sdk/buildbeacon_plugin_sdk.dart';

import '../model/config.dart';
import '../model/led_layout.dart';
import '../model/palette.dart';
import '../model/rgb.dart';
import '../model/tile.dart';
import '../model/zone_action.dart';
import 'led_frame.dart';

/// What an LED shows: a status (hence a color) and a relative intensity,
/// from 0 (off) to 1 (full color).
typedef LedOutput = ({Status status, double intensity});

/// Computes the LED frame.
///
/// Pure function of time: the output loop calls it on every frame
/// (~20 frames/s) with the time elapsed since startup, so all pulsing LEDs
/// stay in sync.
final class FrameRenderer {
  const FrameRenderer({
    this.pulsePeriod = const Duration(seconds: 2),
    this.pulseFloor = 0.15,
    this.identifyPeriod = const Duration(milliseconds: 500),
  });

  /// Duration of one pulse cycle (running / queued).
  final Duration pulsePeriod;

  /// Relative brightness at the bottom of the pulse (0 – 1).
  final double pulseFloor;

  /// Duration of one on/off cycle of the "identify" blinking.
  final Duration identifyPeriod;

  /// Frame of the whole chain at time [t].
  ///
  /// [states] is keyed by source key; a missing source is shown as
  /// `unknown`. The tiles in [identify] (ids) blink white instead of their
  /// normal display. A tile with an invalid chain position is ignored
  /// (reporting it is the job of [Config.validate]).
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

  /// What each LED of a zone shows, in display order.
  ///
  /// Time-independent: also used for the UI preview.
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

  /// Color of an LED at time [t] (intensity and pulse included).
  Rgb colorFor(Palette palette, LedOutput led, Duration t) {
    if (led.intensity <= 0) return Rgb.black;
    final pulse = led.status.pulses ? pulseLevel(t) : 1.0;
    return palette[led.status].scaled(led.intensity * pulse);
  }

  /// Pulse level: [pulseFloor] at t = 0, maximum (1) at half period,
  /// cosine variation.
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

  /// Gauge from left to right. The last lit LED is partly lit, so that
  /// progress moves smoothly: 62 % over 5 LEDs = 3 full, the 4th at 10 %,
  /// the 5th off.
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
