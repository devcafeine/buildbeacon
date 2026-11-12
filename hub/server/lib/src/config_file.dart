// BuildBeacon Hub — Lecture et écriture de config.json.
// Version 1.3 (2026-11-12) — premier démarrage : fichier absent créé avec la master seule.

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
  final Object? json;
  try {
    json = jsonDecode(await file.readAsString());
  } on FormatException catch (e) {
    throw inFile(LocalizedText.same(e.message));
  }
  if (json is! Map<String, Object?>) {
    throw inFile(
      const LocalizedText({
        'en': 'JSON object expected',
        'fr': 'objet JSON attendu',
      }),
    );
  }
  try {
    return Config.fromJson(json);
  } on LocalizedFormatException catch (e) {
    throw inFile(e.text);
  }
}

/// Configuration du fichier [path] ; s'il n'existe pas (premier démarrage),
/// il est créé avec la configuration de départ, la master seule
/// ([Config.initial]), à régler ensuite depuis l'interface web.
///
/// Un fichier présent mais illisible ou refusé n'est jamais remplacé : même
/// erreur que [readConfigFile]. Un dossier impossible à créer lève une
/// [FileSystemException].
Future<({Config config, bool created})> readOrCreateConfigFile(
  String path,
) async {
  if (await FileSystemEntity.type(path) == FileSystemEntityType.notFound) {
    final config = Config.initial();
    await writeConfigFile(path, config);
    return (config: config, created: true);
  }
  return (config: await readConfigFile(path), created: false);
}

/// Enregistre [config] dans [path] de façon atomique : écriture d'un fichier
/// temporaire voisin, puis renommage. Un arrêt brutal pendant l'écriture
/// laisse l'ancien fichier intact.
Future<void> writeConfigFile(String path, Config config) async {
  final file = File(path);
  await file.parent.create(recursive: true);
  final temporary = File('$path.tmp');
  await temporary.writeAsString(
    '${const JsonEncoder.withIndent('  ').convert(config.toJson())}\n',
    flush: true,
  );
  await temporary.rename(file.path);
}
