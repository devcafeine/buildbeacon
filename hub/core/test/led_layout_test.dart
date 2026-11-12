// BuildBeacon Hub — Tests: LED indices in the chain.
// Version 1.4 (2026-11-12) — test names in English.

import 'package:buildbeacon_core/buildbeacon_core.dart';
import 'package:test/test.dart';

Tile _project(int rank) => Tile(
  id: 't$rank',
  label: '',
  kind: TileKind.project,
  chainIndex: rank,
  pos: HexPos(rank, 0),
);

final _master = Tile(
  id: 'master',
  label: '',
  kind: TileKind.master,
  chainIndex: 0,
  pos: const HexPos(0, 1),
);

void main() {
  group('master', () {
    test('system zone = LEDs 0, 1, 2 from left to right', () {
      expect(LedLayout.zoneIndices(TileKind.master, 0, ZoneName.system), [
        0,
        1,
        2,
      ]);
    });

    test('whole tile = its 3 LEDs', () {
      expect(LedLayout.tileIndices(TileKind.master, 0), [0, 1, 2]);
    });
  });

  group('project tile', () {
    test('tile no. k starts at 3 + 9·(k − 1)', () {
      expect([1, 2, 3, 10].map(LedLayout.projectBase), [3, 12, 21, 84]);
    });

    test('tile no. 1 uses LEDs 3 to 11', () {
      expect(LedLayout.tileIndices(TileKind.project, 1), [
        for (var i = 3; i <= 11; i++) i,
      ]);
    });

    test(
      'non-contiguous ambient: top (local 0, 1) then bottom (local 7, 8)',
      () {
        expect(LedLayout.zoneIndices(TileKind.project, 1, ZoneName.ambient), [
          3,
          4,
          10,
          11,
        ]);
        expect(LedLayout.zoneIndices(TileKind.project, 2, ZoneName.ambient), [
          12,
          13,
          19,
          20,
        ]);
      },
    );

    test('dots wired right to left: dot no. 1 = local 6', () {
      expect(LedLayout.zoneIndices(TileKind.project, 1, ZoneName.dots), [
        9,
        8,
        7,
        6,
        5,
      ]);
      expect(LedLayout.zoneIndices(TileKind.project, 2, ZoneName.dots), [
        18,
        17,
        16,
        15,
        14,
      ]);
    });

    test('ambient + dots cover the 9 LEDs, without overlap', () {
      for (var rank = 1; rank <= 5; rank++) {
        final zones = [
          ...LedLayout.zoneIndices(TileKind.project, rank, ZoneName.ambient),
          ...LedLayout.zoneIndices(TileKind.project, rank, ZoneName.dots),
        ]..sort();
        expect(zones, LedLayout.tileIndices(TileKind.project, rank));
      }
    });

    test('chain position < 1 is rejected', () {
      expect(() => LedLayout.projectBase(0), throwsRangeError);
    });
  });

  test('zone not available on the tile kind', () {
    expect(
      () => LedLayout.zoneIndices(TileKind.master, 0, ZoneName.dots),
      throwsArgumentError,
    );
    expect(
      () => LedLayout.zoneIndices(TileKind.project, 1, ZoneName.system),
      throwsArgumentError,
    );
  });

  group('chain length', () {
    test('master tile only: 3 LEDs', () {
      expect(LedLayout.ledCount([_master]), 3);
    });

    test('master + 3 tiles: 3 + 9·3 = 30 LEDs', () {
      expect(
        LedLayout.ledCount([_master, _project(1), _project(2), _project(3)]),
        30,
      );
    });

    test('an unconfigured chain position still counts (LEDs off)', () {
      expect(LedLayout.ledCount([_master, _project(1), _project(3)]), 30);
    });

    test('master tile counts even when missing from the config', () {
      expect(LedLayout.ledCount([_project(1)]), 12);
    });
  });
}
