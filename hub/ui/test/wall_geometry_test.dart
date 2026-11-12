// BuildBeacon UI — Tests: wall geometry (axial ↔ millimeters).
// Version 1.1 (2026-11-12) — comments in English.

import 'package:buildbeacon_core/buildbeacon_core.dart';
import 'package:buildbeacon_ui/src/editor/wall_geometry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('80 mm entre deux tuiles voisines, dans chaque direction', () {
    const origin = HexPos(0, 0);
    for (final (dq, dr) in WallGeometry.neighbors) {
      final distance =
          (WallGeometry.center(HexPos(dq, dr)) - WallGeometry.center(origin))
              .distance;
      expect(distance, closeTo(80, 1e-9));
    }
  });

  test('le centre et les bords d\'une case la désignent', () {
    for (var q = -3; q <= 3; q++) {
      for (var r = -3; r <= 3; r++) {
        final pos = HexPos(q, r);
        final c = WallGeometry.center(pos);
        expect(WallGeometry.hexAt(c), pos);
        expect(WallGeometry.hexAt(c + const Offset(35, 0)), pos);
        expect(WallGeometry.hexAt(c + const Offset(0, -40)), pos);
      }
    }
  });

  test('cases libres voisines : sans les tuiles elles-mêmes', () {
    final free = WallGeometry.freeNeighbors(const [HexPos(0, 0), HexPos(1, 0)]);
    expect(free, hasLength(8));
    expect(free, isNot(contains(const HexPos(0, 0))));
    expect(free, contains(const HexPos(2, 0)));
  });

  test('disposition de l\'utilisateur : master en (0, 1), en escalier', () {
    final bounds = WallGeometry.bounds(const [
      HexPos(0, 0),
      HexPos(0, 1),
      HexPos(1, 1),
    ], padding: 0);
    expect(bounds.width, closeTo(80 * 2.5, 1e-9));
    expect(
      bounds.height,
      closeTo(WallGeometry.radius * 2 + WallGeometry.rowStep, 1e-9),
    );
  });
}
