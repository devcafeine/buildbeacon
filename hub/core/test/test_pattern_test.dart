// BuildBeacon Hub — Tests : mire de mise en service.
// Version 1.1 (2026-11-11) — phases en anglais (ranks, dots, ambient), descriptions traduites.

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

  test('master + 2 tuiles : 21 LED', () {
    expect(pattern.ledCount, 21);
    expect(pattern.frameAt(Duration.zero).length, 21);
  });

  test('phase 1 : chaque tuile de la couleur de son rang', () {
    final frame = pattern.frameAt(s(1));
    expect(pattern.phaseAt(s(1)), TestPatternPhase.ranks);
    expect(at(frame, [0, 1, 2]), everyElement(Rgb.white));
    expect(at(frame, [for (var i = 3; i <= 11; i++) i]), everyElement(red));
    expect(at(frame, [for (var i = 12; i <= 20; i++) i]), everyElement(green));
  });

  test('phase 2 : le point avance de gauche à droite', () {
    // Début : point n° 1 de chaque tuile (LED 9 et 18), LED 0 de la master.
    final start = pattern.frameAt(s(5));
    expect(pattern.phaseAt(s(5)), TestPatternPhase.dots);
    expect(at(start, [9, 8, 7, 6, 5]), [red, off, off, off, off]);
    expect(start[18], green);
    expect(at(start, [0, 1, 2]), [Rgb.white, off, off]);

    // À 2,2 s dans la phase : point n° 3, les précédents en traînée.
    final later = pattern.frameAt(s(7.2));
    final trail = red.scaled(TestPattern.trail);
    expect(at(later, [9, 8, 7, 6, 5]), [trail, trail, red, off, off]);
    expect(at(later, [0, 1, 2]), [
      Rgb.white.scaled(TestPattern.trail),
      Rgb.white,
      off,
    ]);
  });

  test('phase 3 : seulement les rubans du haut et du bas', () {
    final frame = pattern.frameAt(s(11));
    expect(pattern.phaseAt(s(11)), TestPatternPhase.ambient);
    expect(at(frame, [3, 4, 10, 11]), everyElement(red));
    expect(at(frame, [5, 6, 7, 8, 9]), everyElement(off));
    expect(at(frame, [0, 1, 2]), everyElement(off));
  });

  test('le cycle recommence', () {
    expect(pattern.phaseAt(s(15)), TestPatternPhase.ranks);
    expect(TestPattern.colorOf(7), TestPattern.colorOf(1));
  });

  test('descriptions des phases en français et en anglais', () {
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
