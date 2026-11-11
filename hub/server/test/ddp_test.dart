// BuildBeacon Hub — Tests : codage et décodage DDP.
// Version 1.0 (2026-11-11)

import 'dart:typed_data';

import 'package:buildbeacon_hub/buildbeacon_hub.dart';
import 'package:test/test.dart';

void main() {
  group('codage', () {
    test('21 LED : un paquet, DDP v1 + PUSH, type RGB 8 bits, sortie 1', () {
      final rgb = Uint8List.fromList(List.generate(63, (i) => i));
      final [packet] = encodeDdp(rgb, sequence: 3);

      expect(packet.sublist(0, ddpHeaderLength), [
        0x41, // version 1, PUSH
        3, // séquence
        0x0B, // RGB, 8 bits par canal
        0x01, // sortie par défaut
        0, 0, 0, 0, // décalage
        0, 63, // longueur
      ]);
      expect(packet.sublist(ddpHeaderLength), rgb);
    });

    test('la séquence tient sur 4 bits', () {
      expect(encodeDdp(Uint8List(3), sequence: 17).single[1], 1);
    });

    test('600 LED : 480 + 120 LED, PUSH sur le dernier paquet seulement', () {
      final rgb = Uint8List(1800)..fillRange(1440, 1800, 7);
      final [first, second] = [
        for (final p in encodeDdp(rgb, sequence: 1)) DdpPacket.tryParse(p)!,
      ];

      expect((first.offset, first.data.length, first.push), (0, 1440, false));
      expect(
        (second.offset, second.data.length, second.push),
        (1440, 360, true),
      );
      expect(second.data, everyElement(7));
    });

    test('image vide : un paquet PUSH sans données', () {
      final packet = DdpPacket.tryParse(encodeDdp(Uint8List(0)).single)!;
      expect(packet.data, isEmpty);
      expect(packet.push, isTrue);
    });
  });

  group('décodage', () {
    test('aller-retour', () {
      final rgb = Uint8List.fromList([255, 80, 0, 0, 255, 0]);
      final packet = DdpPacket.tryParse(encodeDdp(rgb, sequence: 9).single)!;
      expect(packet.sequence, 9);
      expect(packet.dataType, 0x0B);
      expect(packet.destination, 1);
      expect(packet.offset, 0);
      expect(packet.data, rgb);
    });

    test('paquet tronqué ou d\'une autre version : refusé', () {
      final packet = encodeDdp(Uint8List(6)).single;
      expect(DdpPacket.tryParse(packet.sublist(0, 9)), isNull);
      expect(DdpPacket.tryParse(packet.sublist(0, 12)), isNull);
      expect(
        DdpPacket.tryParse(Uint8List.fromList([0x81, ...packet.sublist(1)])),
        isNull,
      );
    });

    test('en-tête avec horodatage (14 octets)', () {
      final packet = DdpPacket.tryParse(
        Uint8List.fromList([
          0x51, 1, 0x0B, 1, 0, 0, 0, 0, 0, 3, // en-tête, drapeau T
          0xAA, 0xBB, 0xCC, 0xDD, // horodatage
          1, 2, 3,
        ]),
      )!;
      expect(packet.data, [1, 2, 3]);
      expect(packet.push, isTrue);
    });
  });
}
