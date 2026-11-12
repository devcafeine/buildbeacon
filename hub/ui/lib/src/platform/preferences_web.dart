// BuildBeacon UI — Browser preferences: localStorage.
// Version 1.1 (2026-11-12) — comments in English.

import 'package:web/web.dart' as web;

import 'preferences.dart';

final class PlatformPreferences implements Preferences {
  static const _prefix = 'buildbeacon.';

  @override
  String? read(String key) {
    try {
      return web.window.localStorage.getItem('$_prefix$key');
    } on Object {
      return null;
    }
  }

  @override
  void write(String key, String? value) {
    try {
      value == null
          ? web.window.localStorage.removeItem('$_prefix$key')
          : web.window.localStorage.setItem('$_prefix$key', value);
    } on Object {
      // Storage blocked: the choice will not be remembered, no big deal.
    }
  }
}
