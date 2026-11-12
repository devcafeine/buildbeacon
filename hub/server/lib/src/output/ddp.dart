// BuildBeacon Hub — DDP (Distributed Display Protocol): encoding and decoding.
// Version 1.1 (2026-11-12) — comments in English.

import 'dart:math';
import 'dart:typed_data';

/// WLED's UDP port for DDP.
const ddpDefaultPort = 4048;

/// Header length without timecode.
const ddpHeaderLength = 10;

/// Data bytes per packet: 480 RGB LEDs, like WLED.
const ddpMaxDataLength = 1440;

const _version1 = 0x40;
const _versionMask = 0xC0;
const _flagPush = 0x01;
const _flagTimecode = 0x10;

/// RGB, 8 bits per channel, 3 channels (`DDP_TYPE_RGB24` in WLED).
const _typeRgb24 = 0x0B;

/// Default output of the receiver.
const _destinationDisplay = 0x01;

/// Splits an RGB frame into DDP packets, at most 480 LEDs per packet.
///
/// Only the last packet carries the PUSH flag: WLED shows the frame only when
/// it receives it. [sequence] (1 – 15, 0 = unused) lets the receiver discard
/// packets that arrive late.
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

/// Decoded DDP data packet (receiver side: simulator, tests).
final class DdpPacket {
  const DdpPacket({
    required this.flags,
    required this.sequence,
    required this.dataType,
    required this.destination,
    required this.offset,
    required this.data,
  });

  /// Decodes [bytes]; `null` if it is not a complete DDP v1 packet.
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

  /// Position of the data in the frame, in bytes.
  final int offset;
  final Uint8List data;

  /// Last packet of the frame: the receiver displays it.
  bool get push => (flags & _flagPush) != 0;
}
