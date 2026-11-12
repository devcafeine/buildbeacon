// BuildBeacon Hub — Full frame of the LED chain.
// Version 1.1 (2026-11-12) — comments in English.

import 'dart:typed_data';

import '../model/rgb.dart';

/// One color per LED, in chain order (global index).
final class LedFrame {
  LedFrame(int length) : _pixels = List.filled(length, Rgb.black);

  final List<Rgb> _pixels;

  int get length => _pixels.length;

  List<Rgb> get pixels => List.unmodifiable(_pixels);

  Rgb operator [](int index) => _pixels[index];

  void operator []=(int index, Rgb color) => _pixels[index] = color;

  /// R, G, B bytes in sequence: the payload of a DDP packet.
  Uint8List toRgbBytes() {
    final bytes = Uint8List(length * 3);
    for (final (i, color) in _pixels.indexed) {
      bytes[i * 3] = color.r;
      bytes[i * 3 + 1] = color.g;
      bytes[i * 3 + 2] = color.b;
    }
    return bytes;
  }
}
