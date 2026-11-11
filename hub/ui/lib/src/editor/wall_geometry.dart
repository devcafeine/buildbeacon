// BuildBeacon UI — Géométrie du mur : hexagones « pointe en haut », coordonnées axiales.
// Version 1.0 (2026-11-11)

import 'dart:math';
import 'dart:ui';

import 'package:buildbeacon_core/buildbeacon_core.dart';

/// Dimensions réelles en millimètres, comme le simulateur et le modèle
/// OpenSCAD : 80 mm entre côtés plats.
abstract final class WallGeometry {
  /// Distance entre deux côtés plats.
  static const flat = 80.0;

  /// Rayon du cercle circonscrit (centre → pointe).
  static final radius = flat / sqrt(3);

  /// Écart vertical entre deux rangées.
  static final rowStep = flat * sqrt(3) / 2;

  /// Les 6 voisines d'une case, en (dq, dr).
  static const neighbors = [(1, 0), (1, -1), (0, -1), (-1, 0), (-1, 1), (0, 1)];

  /// Position des LED d'une tuile projet depuis son centre, par index local
  /// 0 – 8 (ambiance 0, 1, points 2 – 6 de droite à gauche, ambiance 7, 8).
  static const projectLeds = [
    Offset(-9, -21), Offset(9, -21), //
    Offset(24, 2), Offset(12, 2), Offset(0, 2), Offset(-12, 2), Offset(-24, 2),
    Offset(-9, 25), Offset(9, 25),
  ];

  /// LED de la master, de gauche à droite.
  static const masterLeds = [Offset(-15, 7), Offset(0, 7), Offset(15, 7)];

  static Offset center(HexPos pos) =>
      Offset(flat * (pos.q + pos.r / 2), rowStep * pos.r);

  /// Case qui contient [point] (millimètres).
  static HexPos hexAt(Offset point) {
    final r = point.dy / rowStep;
    final q = point.dx / flat - r / 2;
    return _round(q, r);
  }

  /// Contour d'un hexagone de centre [center], à [scale] × la taille réelle.
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

  /// Cases libres voisines des tuiles : là où l'on peut en ajouter une.
  static Set<HexPos> freeNeighbors(Iterable<HexPos> occupied) {
    final taken = occupied.toSet();
    return {
      for (final pos in taken)
        for (final (dq, dr) in neighbors)
          if (!taken.contains(HexPos(pos.q + dq, pos.r + dr)))
            HexPos(pos.q + dq, pos.r + dr),
    };
  }

  /// Rectangle qui contient les cases [cells], avec une marge [padding].
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

  /// Arrondi d'une position fractionnaire à la case la plus proche
  /// (coordonnées cubiques).
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
