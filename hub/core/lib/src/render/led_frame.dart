// BuildBeacon Hub — Image complète de la chaîne de LED.
// Version 1.0 (2026-11-11)

import 'dart:typed_data';

import '../model/rgb.dart';

/// Une couleur par LED, dans l'ordre de la chaîne (index global).
final class LedFrame {
  LedFrame(int length) : _pixels = List.filled(length, Rgb.black);

  final List<Rgb> _pixels;

  int get length => _pixels.length;

  List<Rgb> get pixels => List.unmodifiable(_pixels);

  Rgb operator [](int index) => _pixels[index];

  void operator []=(int index, Rgb color) => _pixels[index] = color;

  /// Octets R, G, B à la suite, charge utile d'un paquet DDP.
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
