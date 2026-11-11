// BuildBeacon Hub — Simulateur : dessin du panneau dans un terminal (couleurs 24 bits).
// Version 1.1 (2026-11-11) — noms par défaut des tuiles traduits, identifiants en anglais.

import 'dart:math';
import 'dart:typed_data';

import 'package:buildbeacon_core/buildbeacon_core.dart';

/// Largeur visible d'une tuile, en caractères.
const terminalTileWidth = 13;
const _gap = '  ';
const _reset = '\x1b[0m';
const _off = '\x1b[38;2;70;70;70m·$_reset';

/// Dessine les tuiles dans l'ordre de la chaîne, chacune telle qu'on la voit
/// au mur : nom, ruban du haut, points n° 1 → 5 de gauche à droite, ruban du
/// bas. Une LED éteinte apparaît en `·`.
///
/// [labels] : nom des tuiles par rang (0 = master) ; sans nom, « Tile n » ou
/// « Tuile n » selon [language]. [columns] : largeur du terminal, les tuiles
/// passent à la ligne. [raw] : couleurs brutes, sans la correction qui
/// rapproche l'écran du rendu d'une LED.
String renderTerminalPanel(
  Uint8List rgb, {
  Map<int, String> labels = const {},
  int columns = 80,
  bool raw = false,
  String language = fallbackLanguage,
}) {
  final ledCount = rgb.length ~/ 3;
  final projectTiles = max(
    0,
    (ledCount - LedLayout.masterLeds + LedLayout.projectLeds - 1) ~/
        LedLayout.projectLeds,
  );

  String led(int index) {
    if (index >= ledCount) return ' ';
    final (r, g, b) = (rgb[index * 3], rgb[index * 3 + 1], rgb[index * 3 + 2]);
    if (r == 0 && g == 0 && b == 0) return _off;
    final (sr, sg, sb) = raw ? (r, g, b) : (_screen(r), _screen(g), _screen(b));
    return '\x1b[38;2;$sr;$sg;${sb}m●$_reset';
  }

  final tiles = [
    [
      _center(labels[0] ?? 'Master'),
      ' ' * terminalTileWidth,
      '   ${led(0)}  ${led(1)}  ${led(2)}   ',
      ' ' * terminalTileWidth,
    ],
    for (var rank = 1; rank <= projectTiles; rank++)
      () {
        final base = LedLayout.projectBase(rank);
        String at(int local) => led(base + local);
        return [
          _center(
            labels[rank] ?? tr(language, en: 'Tile $rank', fr: 'Tuile $rank'),
          ),
          '    ${at(0)}   ${at(1)}    ',
          '  ${[for (final local in LedLayout.dotsLocal) at(local)].join(' ')}  ',
          '    ${at(7)}   ${at(8)}    ',
        ];
      }(),
  ];

  final perRow = max(
    1,
    (columns + _gap.length) ~/ (terminalTileWidth + _gap.length),
  );
  final lines = <String>[];
  for (var start = 0; start < tiles.length; start += perRow) {
    final row = tiles.sublist(start, min(start + perRow, tiles.length));
    if (start > 0) lines.add('');
    for (var line = 0; line < 4; line++) {
      lines.add([for (final tile in row) tile[line]].join(_gap).trimRight());
    }
  }
  return lines.join('\n');
}

/// Nom centré sur la largeur d'une tuile, raccourci s'il dépasse.
String _center(String text) {
  final shown = text.length > terminalTileWidth - 2
      ? '${text.substring(0, terminalTileWidth - 3)}…'
      : text;
  final left = (terminalTileWidth - shown.length) ~/ 2;
  return ' ' * left + shown + ' ' * (terminalTileWidth - left - shown.length);
}

/// Une LED à faible intensité paraît plus lumineuse qu'un pixel d'écran de
/// même valeur : correction gamma 2,2, comme l'aperçu web.
int _screen(int channel) => (255 * pow(channel / 255, 1 / 2.2)).round();
