// BuildBeacon Hub — 8-bit RGB color.
// Version 1.2 (2026-11-12) — comments in English.

import 'package:buildbeacon_plugin_sdk/buildbeacon_plugin_sdk.dart';

/// Color with 8 bits per channel, always in logical RGB order.
///
/// The physical order of the WS2812B (GRB) is handled by WLED: the Hub does not deal with it.
final class Rgb {
  const Rgb(this.r, this.g, this.b)
    : assert(r >= 0 && r <= 255),
      assert(g >= 0 && g <= 255),
      assert(b >= 0 && b <= 255);

  /// Reads a color in `#RRGGBB` format (the `#` is optional, case-insensitive).
  factory Rgb.parse(String hex) {
    final digits = hex.startsWith('#') ? hex.substring(1) : hex;
    if (!_hexPattern.hasMatch(digits)) {
      throw LocalizedFormatException(
        LocalizedText.build(
          (l) => tr(
            l,
            en: 'Invalid color "$hex": #RRGGBB expected',
            fr: 'Couleur invalide « $hex » : #RRGGBB attendu',
          ),
        ),
        hex,
      );
    }
    final value = int.parse(digits, radix: 16);
    return Rgb((value >> 16) & 0xFF, (value >> 8) & 0xFF, value & 0xFF);
  }

  static const black = Rgb(0, 0, 0);
  static const white = Rgb(255, 255, 255);

  static final _hexPattern = RegExp(r'^[0-9a-fA-F]{6}$');

  final int r;
  final int g;
  final int b;

  /// Dimmed color: each channel is multiplied by [factor] (clamped to 0 – 1).
  Rgb scaled(double factor) {
    final f = factor.clamp(0.0, 1.0);
    return Rgb((r * f).round(), (g * f).round(), (b * f).round());
  }

  /// `#RRGGBB` format, in uppercase.
  String toHex() => '#${_hex2(r)}${_hex2(g)}${_hex2(b)}';

  static String _hex2(int channel) =>
      channel.toRadixString(16).padLeft(2, '0').toUpperCase();

  @override
  bool operator ==(Object other) =>
      other is Rgb && other.r == r && other.g == g && other.b == b;

  @override
  int get hashCode => Object.hash(r, g, b);

  @override
  String toString() => 'Rgb(${toHex()})';
}
