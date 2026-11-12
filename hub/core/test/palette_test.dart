// BuildBeacon Hub — Tests: color of each status.
// Version 1.3 (2026-11-12) — test names in English.

import 'package:buildbeacon_core/buildbeacon_core.dart';
import 'package:test/test.dart';

void main() {
  final palette = Palette();

  test('green, yellow, red, orange, blue, dim grey', () {
    expect(palette[Status.success], const Rgb(0, 255, 0));
    expect(palette[Status.warning], const Rgb(255, 170, 0));
    expect(palette[Status.failure], const Rgb(255, 0, 0));
    expect(palette[Status.running], const Rgb(255, 80, 0));
    expect(palette[Status.queued], palette[Status.running]);
    expect(palette[Status.cancelled], const Rgb(0, 64, 255));
    expect(palette[Status.unknown], const Rgb(32, 32, 32));
  });

  test('only "running" and "queued" pulse', () {
    expect(
      Status.values.where((s) => s.pulses),
      unorderedEquals([Status.running, Status.queued]),
    );
  });

  test('JSON keys in English', () {
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
