// BuildBeacon Hub — Protocole DDP (Distributed Display Protocol) : codage et décodage.
// Version 1.0 (2026-11-11)

import 'dart:math';
import 'dart:typed_data';

/// Port UDP de DDP chez WLED.
const ddpDefaultPort = 4048;

/// Longueur de l'en-tête sans horodatage.
const ddpHeaderLength = 10;

/// Octets de données par paquet : 480 LED RGB, comme WLED.
const ddpMaxDataLength = 1440;

const _version1 = 0x40;
const _versionMask = 0xC0;
const _flagPush = 0x01;
const _flagTimecode = 0x10;

/// RGB, 8 bits par canal, 3 canaux (`DDP_TYPE_RGB24` chez WLED).
const _typeRgb24 = 0x0B;

/// Sortie par défaut du récepteur.
const _destinationDisplay = 0x01;

/// Découpe une image RGB en paquets DDP, 480 LED au plus par paquet.
///
/// Seul le dernier paquet porte le drapeau PUSH : WLED n'affiche l'image qu'à
/// sa réception. [sequence] (1 – 15, 0 = non utilisé) permet au récepteur
/// d'écarter des paquets arrivés en retard.
List<Uint8List> encodeDdp(Uint8List rgb, {int sequence = 0}) {
  final packets = <Uint8List>[];
  var offset = 0;
  do {
    final length = min(ddpMaxDataLength, rgb.length - offset);
    final last = offset + length >= rgb.length;
    final packet = Uint8List(ddpHeaderLength + length)
      ..[0] = _version1 | (last ? _flagPush : 0)
      ..[1] = sequence & 0x0F
      ..[2] = _typeRgb24
      ..[3] = _destinationDisplay
      ..setRange(ddpHeaderLength, ddpHeaderLength + length, rgb, offset);
    ByteData.sublistView(packet)
      ..setUint32(4, offset)
      ..setUint16(8, length);
    packets.add(packet);
    offset += length;
  } while (offset < rgb.length);
  return packets;
}

/// Paquet DDP de données décodé (côté récepteur : simulateur, tests).
final class DdpPacket {
  const DdpPacket({
    required this.flags,
    required this.sequence,
    required this.dataType,
    required this.destination,
    required this.offset,
    required this.data,
  });

  /// Décode [bytes] ; `null` si ce n'est pas un paquet DDP v1 complet.
  static DdpPacket? tryParse(Uint8List bytes) {
    if (bytes.length < ddpHeaderLength) return null;
    final flags = bytes[0];
    if ((flags & _versionMask) != _version1) return null;
    final header = (flags & _flagTimecode) != 0
        ? ddpHeaderLength + 4
        : ddpHeaderLength;
    if (bytes.length < header) return null;
    final view = ByteData.sublistView(bytes);
    final length = view.getUint16(8);
    if (bytes.length < header + length) return null;
    return DdpPacket(
      flags: flags,
      sequence: bytes[1] & 0x0F,
      dataType: bytes[2],
      destination: bytes[3],
      offset: view.getUint32(4),
      data: Uint8List.sublistView(bytes, header, header + length),
    );
  }

  final int flags;
  final int sequence;
  final int dataType;
  final int destination;

  /// Position des données dans l'image, en octets.
  final int offset;
  final Uint8List data;

  /// Dernier paquet de l'image : le récepteur l'affiche.
  bool get push => (flags & _flagPush) != 0;
}
