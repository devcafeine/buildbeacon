// BuildBeacon Hub — Lecture de config.json.
// Version 1.1 (2026-11-11) — erreurs traduites.

import 'dart:convert';
import 'dart:io';

import 'package:buildbeacon_core/buildbeacon_core.dart';

/// Lit la configuration du fichier [path]. Lève une
/// [LocalizedFormatException] dont le message cite le fichier (absent, JSON
/// invalide, contenu refusé).
Future<Config> readConfigFile(String path) async {
  LocalizedFormatException inFile(LocalizedText message) =>
      LocalizedFormatException(
        LocalizedText.build(
          (l) => tr(
            l,
            en: '$path: ${message.resolve(l)}',
            fr: '$path : ${message.resolve(l)}',
          ),
        ),
      );

  final file = File(path);
  if (!await file.exists()) {
    throw inFile(
      const LocalizedText({
        'en': 'file not found',
        'fr': 'fichier introuvable',
      }),
    );
  }
  try {
    final json = jsonDecode(await file.readAsString());
    if (json is! Map<String, Object?>) {
      throw inFile(
        const LocalizedText({
          'en': 'JSON object expected',
          'fr': 'objet JSON attendu',
        }),
      );
    }
    return Config.fromJson(json);
  } on LocalizedFormatException catch (e) {
    throw inFile(e.text);
  } on FormatException catch (e) {
    throw inFile(LocalizedText.same(e.message));
  }
}
