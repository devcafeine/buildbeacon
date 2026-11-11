// BuildBeacon Hub — Tests : dessin du panneau dans le terminal (simulateur).
// Version 1.1 (2026-11-11) — noms par défaut des tuiles traduits.

import 'dart:typed_data';

import 'package:buildbeacon_hub/buildbeacon_hub.dart';
import 'package:test/test.dart';

/// Retire les codes couleur ANSI.
String _plain(String text) => text.replaceAll(RegExp(r'\x1b\[[0-9;]*m'), '');

Uint8List _frame(Map<int, (int, int, int)> leds, {int ledCount = 21}) {
  final rgb = Uint8List(ledCount * 3);
  for (final MapEntry(key: i, value: (r, g, b)) in leds.entries) {
    rgb.setAll(i * 3, [r, g, b]);
  }
  return rgb;
}

void main() {
  test('master puis tuiles dans l\'ordre de la chaîne, avec leurs noms', () {
    final lines = _plain(
      renderTerminalPanel(_frame({}), labels: {0: 'BuildBeacon', 1: 'App'}),
    ).split('\n');

    expect(lines, hasLength(4));
    expect(
      lines[0],
      allOf(contains('BuildBeacon'), contains('App'), contains('Tile 2')),
    );
    // Ligne du milieu : 3 LED de la master + 5 points par tuile, toutes éteintes.
    expect(lines[2].trim().split(RegExp(r'\s+')), List.filled(13, '·'));
  });

  test('noms par défaut en français', () {
    final text = _plain(renderTerminalPanel(_frame({}), language: 'fr'));
    expect(text, allOf(contains('Tuile 1'), contains('Tuile 2')));
  });

  test('point n° 1 (LED 9) à gauche, point n° 5 (LED 5) à droite', () {
    final line = renderTerminalPanel(
      _frame({9: (255, 0, 0), 5: (0, 0, 255)}),
      raw: true,
    ).split('\n')[2];
    expect(
      line.indexOf('38;2;255;0;0m'),
      lessThan(line.indexOf('38;2;0;0;255m')),
    );
  });

  test('ambiance : rubans du haut (LED 3, 4) et du bas (LED 10, 11)', () {
    final lines = renderTerminalPanel(
      _frame({3: (1, 0, 0), 4: (2, 0, 0), 10: (3, 0, 0), 11: (4, 0, 0)}),
      raw: true,
    ).split('\n');
    expect(lines[1], allOf(contains('38;2;1;0;0m'), contains('38;2;2;0;0m')));
    expect(lines[3], allOf(contains('38;2;3;0;0m'), contains('38;2;4;0;0m')));
  });

  test('correction pour l\'écran : une LED faible paraît plus claire', () {
    final frame = _frame({0: (38, 12, 0)});
    expect(renderTerminalPanel(frame, raw: true), contains('38;2;38;12;0m'));
    expect(renderTerminalPanel(frame), contains('38;2;107;64;0m'));
  });

  test('les tuiles passent à la ligne selon la largeur du terminal', () {
    final lines = _plain(
      renderTerminalPanel(_frame({}), columns: 30),
    ).split('\n');
    expect(lines, hasLength(9)); // 2 tuiles, ligne vide, 1 tuile
    expect(lines[5], contains('Tile 2'));
  });

  test('nom trop long : raccourci', () {
    final text = _plain(
      renderTerminalPanel(
        _frame({}),
        labels: {1: 'Un très long nom de projet'},
      ),
    );
    expect(text, contains('Un très lo…'));
  });
}
