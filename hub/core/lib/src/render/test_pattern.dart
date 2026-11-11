// BuildBeacon Hub — Mire de mise en service : vérifie le câblage d'un panneau.
// Version 1.1 (2026-11-11) — phases en anglais (ranks, dots, ambient), descriptions traduites.

import 'package:buildbeacon_plugin_sdk/buildbeacon_plugin_sdk.dart';

import '../model/led_layout.dart';
import '../model/rgb.dart';
import '../model/tile.dart';
import 'led_frame.dart';

/// Étapes de la mire, avec ce qu'il faut vérifier sur le panneau.
enum TestPatternPhase {
  ranks(
    LocalizedText({
      'en':
          'Tile ranks: each tile has its color, in chain order (master white, '
          'then #1 red, #2 green, #3 blue, #4 yellow, #5 magenta, #6 cyan).',
      'fr':
          'Rang des tuiles : chaque tuile a sa couleur, dans l\'ordre de la '
          'chaîne (master blanche, puis n° 1 rouge, n° 2 vert, n° 3 bleu, '
          'n° 4 jaune, n° 5 magenta, n° 6 cyan).',
    }),
  ),
  dots(
    LocalizedText({
      'en':
          'Dot direction: on each tile, a dot moves from #1 to #5. It must go '
          'from left to right (the master too).',
      'fr':
          'Sens des points : sur chaque tuile, un point avance du n° 1 au '
          'n° 5. Il doit aller de gauche à droite (la master aussi).',
    }),
  ),
  ambient(
    LocalizedText({
      'en': 'Ambient zone: only the top and bottom strips light up.',
      'fr': 'Zone ambiance : seuls les rubans du haut et du bas s\'allument.',
    }),
  );

  const TestPatternPhase(this.description);

  final LocalizedText description;
}

/// Mire de mise en service, calculée à partir de la topologie du câblage
/// (`LedLayout`) : si le panneau ne fait pas ce qu'annonce la phase, le
/// câblage diffère de la spécification.
final class TestPattern {
  const TestPattern({
    required this.projectTiles,
    this.phaseDuration = const Duration(seconds: 5),
  });

  /// Couleurs des rangs 1, 2, 3… (puis on recommence).
  static const rankColors = [
    Rgb(255, 0, 0),
    Rgb(0, 255, 0),
    Rgb(0, 0, 255),
    Rgb(255, 200, 0),
    Rgb(255, 0, 255),
    Rgb(0, 255, 255),
  ];

  static const masterColor = Rgb.white;

  /// Intensité des points déjà passés pendant le balayage.
  static const trail = 0.15;

  /// Couleur de la tuile au rang [rank] (1, 2, …).
  static Rgb colorOf(int rank) => rankColors[(rank - 1) % rankColors.length];

  /// Nombre de tuiles projet chaînées après la master.
  final int projectTiles;
  final Duration phaseDuration;

  int get ledCount =>
      LedLayout.masterLeds + LedLayout.projectLeds * projectTiles;

  TestPatternPhase phaseAt(Duration t) =>
      TestPatternPhase.values[(t.inMicroseconds ~/
              phaseDuration.inMicroseconds) %
          TestPatternPhase.values.length];

  LedFrame frameAt(Duration t) {
    final frame = LedFrame(ledCount);
    final elapsedInPhase = t.inMicroseconds % phaseDuration.inMicroseconds;
    final ranks = [for (var rank = 1; rank <= projectTiles; rank++) rank];

    switch (phaseAt(t)) {
      case TestPatternPhase.ranks:
        _fill(frame, LedLayout.systemIndices, masterColor);
        for (final rank in ranks) {
          _fill(
            frame,
            LedLayout.tileIndices(TileKind.project, rank),
            colorOf(rank),
          );
        }
      case TestPatternPhase.dots:
        _sweep(frame, LedLayout.systemIndices, masterColor, elapsedInPhase);
        for (final rank in ranks) {
          _sweep(
            frame,
            LedLayout.zoneIndices(TileKind.project, rank, ZoneName.dots),
            colorOf(rank),
            elapsedInPhase,
          );
        }
      case TestPatternPhase.ambient:
        for (final rank in ranks) {
          _fill(
            frame,
            LedLayout.zoneIndices(TileKind.project, rank, ZoneName.ambient),
            colorOf(rank),
          );
        }
    }
    return frame;
  }

  static void _fill(LedFrame frame, List<int> indices, Rgb color) {
    for (final i in indices) {
      frame[i] = color;
    }
  }

  /// Allume une LED après l'autre dans l'ordre d'affichage (gauche → droite),
  /// les précédentes restant faiblement allumées pour montrer le sens.
  void _sweep(LedFrame frame, List<int> indices, Rgb color, int elapsed) {
    final current = elapsed * indices.length ~/ phaseDuration.inMicroseconds;
    for (var i = 0; i <= current; i++) {
      frame[indices[i]] = i == current ? color : color.scaled(trail);
    }
  }
}
