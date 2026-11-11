// BuildBeacon Hub — Tests : index des LED dans la chaîne.
// Version 1.2 (2026-11-11) — identifiants en anglais (project, ambient, dots, system).

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
    test('zone système = LED 0, 1, 2 de gauche à droite', () {
      expect(LedLayout.zoneIndices(TileKind.master, 0, ZoneName.system), [
        0,
        1,
        2,
      ]);
    });

    test('la tuile entière = ses 3 LED', () {
      expect(LedLayout.tileIndices(TileKind.master, 0), [0, 1, 2]);
    });
  });

  group('tuile projet', () {
    test('la tuile n° k commence à 3 + 9·(k − 1)', () {
      expect([1, 2, 3, 10].map(LedLayout.projectBase), [3, 12, 21, 84]);
    });

    test('la tuile n° 1 occupe les LED 3 à 11', () {
      expect(LedLayout.tileIndices(TileKind.project, 1), [
        for (var i = 3; i <= 11; i++) i,
      ]);
    });

    test('ambiance non contiguë : haut (local 0, 1) puis bas (local 7, 8)', () {
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
    });

    test('points câblés de droite à gauche : point n° 1 = local 6', () {
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

    test('ambiance + points couvrent les 9 LED, sans recouvrement', () {
      for (var rank = 1; rank <= 5; rank++) {
        final zones = [
          ...LedLayout.zoneIndices(TileKind.project, rank, ZoneName.ambient),
          ...LedLayout.zoneIndices(TileKind.project, rank, ZoneName.dots),
        ]..sort();
        expect(zones, LedLayout.tileIndices(TileKind.project, rank));
      }
    });

    test('un rang < 1 est refusé', () {
      expect(() => LedLayout.projectBase(0), throwsRangeError);
    });
  });

  test('zone absente du type de tuile', () {
    expect(
      () => LedLayout.zoneIndices(TileKind.master, 0, ZoneName.dots),
      throwsArgumentError,
    );
    expect(
      () => LedLayout.zoneIndices(TileKind.project, 1, ZoneName.system),
      throwsArgumentError,
    );
  });

  group('longueur de la chaîne', () {
    test('master seule : 3 LED', () {
      expect(LedLayout.ledCount([_master]), 3);
    });

    test('master + 3 tuiles : 3 + 9·3 = 30 LED', () {
      expect(
        LedLayout.ledCount([_master, _project(1), _project(2), _project(3)]),
        30,
      );
    });

    test('un rang non configuré compte quand même (LED éteintes)', () {
      expect(LedLayout.ledCount([_master, _project(1), _project(3)]), 30);
    });

    test('la master compte même absente de la config', () {
      expect(LedLayout.ledCount([_project(1)]), 12);
    });
  });
}
