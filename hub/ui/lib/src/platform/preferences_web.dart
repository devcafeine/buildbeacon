// BuildBeacon UI — Préférences du navigateur : localStorage.
// Version 1.0 (2026-11-11)

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
      // Stockage bloqué : le choix ne sera pas retenu, rien de grave.
    }
  }
}
