// BuildBeacon Hub — Mapping between zones and LED indices in the chain.
// Version 1.2 (2026-11-12) — comments in English.

import 'dart:math';

import 'tile.dart';

/// Chain topology: the master tile (3 LEDs, indices 0 – 2), then the project
/// tiles in wiring order, 9 LEDs each.
abstract final class LedLayout {
  static const masterLeds = 3;
  static const projectLeds = 9;

  /// System zone of the master tile, from left to right.
  static const systemIndices = [0, 1, 2];

  /// Local indices of the ambient zone: top strip (0, 1) and bottom strip (7, 8).
  static const ambientLocal = [0, 1, 7, 8];

  /// Local indices of the dots, from #1 (left) to #5 (right): the middle
  /// strip is wired from right to left.
  static const dotsLocal = [6, 5, 4, 3, 2];

  /// First global index of the project tile at chain position [chainIndex] (≥ 1).
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

  /// Global indices of [zone], in display order (left → right; for the
  /// ambient zone: top then bottom).
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

  /// All global indices of a tile, in chain order.
  static List<int> tileIndices(TileKind kind, int chainIndex) => switch (kind) {
    TileKind.master => systemIndices,
    TileKind.project => [
      for (var i = 0; i < projectLeds; i++) projectBase(chainIndex) + i,
    ],
  };

  /// Chain length: the master tile (always physically present) plus the
  /// project tiles up to the farthest one. A chain position without a
  /// configured tile stays off.
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
