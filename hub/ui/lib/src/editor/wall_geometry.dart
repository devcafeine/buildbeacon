// BuildBeacon UI — Wall geometry: pointy-top hexagons, axial coordinates.
// Version 1.1 (2026-11-12) — comments in English.

import 'dart:math';
import 'dart:ui';

import 'package:buildbeacon_core/buildbeacon_core.dart';

/// Real dimensions in millimeters, like the simulator and the OpenSCAD
/// model: 80 mm between flat sides.
abstract final class WallGeometry {
  /// Distance between two flat sides.
  static const flat = 80.0;

  /// Radius of the circumscribed circle (center → tip).
  static final radius = flat / sqrt(3);

  /// Vertical distance between two rows.
  static final rowStep = flat * sqrt(3) / 2;

  /// The 6 neighbors of a cell, as (dq, dr).
  static const neighbors = [(1, 0), (1, -1), (0, -1), (-1, 0), (-1, 1), (0, 1)];

  /// Position of a project tile's LEDs from its center, by local index
  /// 0 – 8 (ambient 0, 1, dots 2 – 6 from right to left, ambient 7, 8).
  static const projectLeds = [
    Offset(-9, -21), Offset(9, -21), //
    Offset(24, 2), Offset(12, 2), Offset(0, 2), Offset(-12, 2), Offset(-24, 2),
    Offset(-9, 25), Offset(9, 25),
  ];

  /// LEDs of the master tile, from left to right.
  static const masterLeds = [Offset(-15, 7), Offset(0, 7), Offset(15, 7)];

  static Offset center(HexPos pos) =>
      Offset(flat * (pos.q + pos.r / 2), rowStep * pos.r);

  /// Cell that contains [point] (millimeters).
  static HexPos hexAt(Offset point) {
    final r = point.dy / rowStep;
    final q = point.dx / flat - r / 2;
    return _round(q, r);
  }

  /// Outline of a hexagon centered on [center], at [scale] × the real size.
  static Path hexagon(Offset center, {double scale = 1}) {
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final angle = pi / 180 * (60 * i - 90);
      final point = center + Offset(cos(angle), sin(angle)) * (radius * scale);
      i == 0
          ? path.moveTo(point.dx, point.dy)
          : path.lineTo(point.dx, point.dy);
    }
    return path..close();
  }

  /// Free cells next to the tiles: where one can be added.
  static Set<HexPos> freeNeighbors(Iterable<HexPos> occupied) {
    final taken = occupied.toSet();
    return {
      for (final pos in taken)
        for (final (dq, dr) in neighbors)
          if (!taken.contains(HexPos(pos.q + dq, pos.r + dr)))
            HexPos(pos.q + dq, pos.r + dr),
    };
  }

  /// Rectangle that contains the cells [cells], with a [padding] margin.
  static Rect bounds(Iterable<HexPos> cells, {double padding = 6}) {
    final centers = cells.map(center).toList();
    if (centers.isEmpty) {
      return Rect.fromCircle(center: Offset.zero, radius: radius + padding);
    }
    final halfWidth = flat / 2 + padding;
    final halfHeight = radius + padding;
    return Rect.fromLTRB(
      centers.map((c) => c.dx).reduce(min) - halfWidth,
      centers.map((c) => c.dy).reduce(min) - halfHeight,
      centers.map((c) => c.dx).reduce(max) + halfWidth,
      centers.map((c) => c.dy).reduce(max) + halfHeight,
    );
  }

  /// Rounds a fractional position to the nearest cell (cube
  /// coordinates).
  static HexPos _round(double q, double r) {
    final s = -q - r;
    var rq = q.round();
    var rr = r.round();
    final rs = s.round();
    final dq = (rq - q).abs();
    final dr = (rr - r).abs();
    final ds = (rs - s).abs();
    if (dq > dr && dq > ds) {
      rq = -rr - rs;
    } else if (dr > ds) {
      rr = -rq - rs;
    }
    return HexPos(rq, rr);
  }
}
