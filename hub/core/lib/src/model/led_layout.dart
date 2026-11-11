// BuildBeacon Hub — Correspondance zones ↔ index de LED de la chaîne.
// Version 1.1 (2026-11-11) — identifiants en anglais (ambient, dots, system).

import 'dart:math';

import 'tile.dart';

/// Topologie de la chaîne : la master (3 LED, index 0 – 2) puis les tuiles
/// projet dans l'ordre de câblage, 9 LED chacune.
abstract final class LedLayout {
  static const masterLeds = 3;
  static const projectLeds = 9;

  /// Zone système de la master, de gauche à droite.
  static const systemIndices = [0, 1, 2];

  /// Index locaux de la zone ambiance : ruban du haut (0, 1) et du bas (7, 8).
  static const ambientLocal = [0, 1, 7, 8];

  /// Index locaux des points, du n° 1 (à gauche) au n° 5 (à droite) :
  /// le ruban du milieu est câblé de droite à gauche.
  static const dotsLocal = [6, 5, 4, 3, 2];

  /// Premier index global de la tuile projet au rang [chainIndex] (≥ 1).
  static int projectBase(int chainIndex) {
    if (chainIndex < 1) {
      throw RangeError.value(
        chainIndex,
        'chainIndex',
        'A project tile has a chain position of 1 or more',
      );
    }
    return masterLeds + projectLeds * (chainIndex - 1);
  }

  /// Index globaux de [zone], dans l'ordre d'affichage (gauche → droite ;
  /// pour l'ambiance : haut puis bas).
  static List<int> zoneIndices(TileKind kind, int chainIndex, ZoneName zone) =>
      switch ((kind, zone)) {
        (TileKind.master, ZoneName.system) => systemIndices,
        (TileKind.project, ZoneName.ambient) => _offset(
          ambientLocal,
          projectBase(chainIndex),
        ),
        (TileKind.project, ZoneName.dots) => _offset(
          dotsLocal,
          projectBase(chainIndex),
        ),
        _ => throw ArgumentError('No ${zone.name} zone on a ${kind.name} tile'),
      };

  /// Tous les index globaux d'une tuile, dans l'ordre de la chaîne.
  static List<int> tileIndices(TileKind kind, int chainIndex) => switch (kind) {
    TileKind.master => systemIndices,
    TileKind.project => [
      for (var i = 0; i < projectLeds; i++) projectBase(chainIndex) + i,
    ],
  };

  /// Longueur de la chaîne : la master (toujours présente physiquement) plus
  /// les tuiles projet jusqu'à la plus éloignée. Un rang sans tuile configurée
  /// reste éteint.
  static int ledCount(Iterable<Tile> tiles) {
    final lastRank = tiles
        .where((t) => t.kind == TileKind.project)
        .map((t) => t.chainIndex)
        .fold<int>(0, max);
    return masterLeds + projectLeds * lastRank;
  }

  static List<int> _offset(List<int> local, int base) => [
    for (final i in local) base + i,
  ];
}
