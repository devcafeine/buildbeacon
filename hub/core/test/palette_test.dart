// BuildBeacon Hub — Tests: color of each status.
// Version 1.2 (2026-11-12) — comments in English.

import 'package:buildbeacon_core/buildbeacon_core.dart';
import 'package:test/test.dart';

void main() {
  final palette = Palette();

  test('vert, jaune, rouge, orange, bleu, gris faible', () {
    expect(palette[Status.success], const Rgb(0, 255, 0));
    expect(palette[Status.warning], const Rgb(255, 170, 0));
    expect(palette[Status.failure], const Rgb(255, 0, 0));
    expect(palette[Status.running], const Rgb(255, 80, 0));
    expect(palette[Status.queued], palette[Status.running]);
    expect(palette[Status.cancelled], const Rgb(0, 64, 255));
    expect(palette[Status.unknown], const Rgb(32, 32, 32));
  });

  test('seuls « en cours » et « en file » pulsent', () {
    expect(
      Status.values.where((s) => s.pulses),
      unorderedEquals([Status.running, Status.queued]),
    );
  });

  test('clés JSON en anglais', () {
    expect(palette.toJson().keys, [
      'success',
      'warning',
      'failure',
      'running',
      'queued',
      'cancelled',
      'unknown',
    ]);
  });
}
