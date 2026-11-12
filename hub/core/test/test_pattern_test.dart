// BuildBeacon Hub — Tests: commissioning test pattern.
// Version 1.3 (2026-11-12) — test names in English.

import 'package:buildbeacon_core/buildbeacon_core.dart';
import 'package:test/test.dart';

void main() {
  const pattern = TestPattern(projectTiles: 2);
  const off = Rgb.black;
  const red = Rgb(255, 0, 0);
  const green = Rgb(0, 255, 0);

  List<Rgb> at(LedFrame frame, List<int> indices) => [
    for (final i in indices) frame[i],
  ];

  Duration s(double seconds) =>
      Duration(microseconds: (seconds * 1000000).round());

  test('master + 2 tiles: 21 LEDs', () {
    expect(pattern.ledCount, 21);
    expect(pattern.frameAt(Duration.zero).length, 21);
  });

  test('phase 1: each tile in the color of its chain position', () {
    final frame = pattern.frameAt(s(1));
    expect(pattern.phaseAt(s(1)), TestPatternPhase.ranks);
    expect(at(frame, [0, 1, 2]), everyElement(Rgb.white));
    expect(at(frame, [for (var i = 3; i <= 11; i++) i]), everyElement(red));
    expect(at(frame, [for (var i = 12; i <= 20; i++) i]), everyElement(green));
  });

  test('phase 2: the dot moves from left to right', () {
    // Start: dot #1 of each tile (LEDs 9 and 18), LED 0 of the master tile.
    final start = pattern.frameAt(s(5));
    expect(pattern.phaseAt(s(5)), TestPatternPhase.dots);
    expect(at(start, [9, 8, 7, 6, 5]), [red, off, off, off, off]);
    expect(start[18], green);
    expect(at(start, [0, 1, 2]), [Rgb.white, off, off]);

    // At 2.2 s into the phase: dot #3, the previous ones as a trail.
    final later = pattern.frameAt(s(7.2));
    final trail = red.scaled(TestPattern.trail);
    expect(at(later, [9, 8, 7, 6, 5]), [trail, trail, red, off, off]);
    expect(at(later, [0, 1, 2]), [
      Rgb.white.scaled(TestPattern.trail),
      Rgb.white,
      off,
    ]);
  });

  test('phase 3: only the top and bottom strips', () {
    final frame = pattern.frameAt(s(11));
    expect(pattern.phaseAt(s(11)), TestPatternPhase.ambient);
    expect(at(frame, [3, 4, 10, 11]), everyElement(red));
    expect(at(frame, [5, 6, 7, 8, 9]), everyElement(off));
    expect(at(frame, [0, 1, 2]), everyElement(off));
  });

  test('the cycle starts over', () {
    expect(pattern.phaseAt(s(15)), TestPatternPhase.ranks);
    expect(TestPattern.colorOf(7), TestPattern.colorOf(1));
  });

  test('phase descriptions in French and English', () {
    expect(
      TestPatternPhase.dots.description.resolve('fr'),
      startsWith('Sens des points'),
    );
    expect(
      TestPatternPhase.dots.description.resolve('en'),
      startsWith('Dot direction'),
    );
  });
}
