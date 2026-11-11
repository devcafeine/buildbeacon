// BuildBeacon Hub — Lecture d'un fichier .env (variables d'environnement).
// Version 1.0 (2026-11-11)

import 'dart:io';

final _validKey = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$');

/// Lit le contenu d'un fichier `.env` : lignes `NOM=valeur`, commentaires `#`,
/// guillemets facultatifs autour de la valeur, préfixe `export ` accepté. Les
/// lignes illisibles sont ignorées.
Map<String, String> parseEnvFile(String content) {
  final values = <String, String>{};
  for (final raw in content.split('\n')) {
    var line = raw.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    if (line.startsWith('export ')) line = line.substring(7).trimLeft();
    final equals = line.indexOf('=');
    if (equals <= 0) continue;
    final key = line.substring(0, equals).trim();
    if (!_validKey.hasMatch(key)) continue;
    values[key] = _value(line.substring(equals + 1).trim());
  }
  return values;
}

String _value(String text) {
  final quoted =
      text.length >= 2 &&
      ((text.startsWith('"') && text.endsWith('"')) ||
          (text.startsWith("'") && text.endsWith("'")));
  if (quoted) return text.substring(1, text.length - 1);
  final comment = text.indexOf(' #');
  return comment < 0 ? text : text.substring(0, comment).trimRight();
}

/// Environnement du Hub : les variables du fichier [envFile] s'il existe,
/// puis celles du processus, qui ont priorité. Les valeurs vides sont
/// ignorées (un `.env` copié de `.env.example` sans être rempli).
Future<Map<String, String>> loadEnvironment({
  String? envFile,
  Map<String, String>? processEnvironment,
}) async {
  final file = envFile == null ? null : File(envFile);
  final fromFile = file != null && await file.exists()
      ? parseEnvFile(await file.readAsString())
      : const <String, String>{};
  return {...fromFile, ...(processEnvironment ?? Platform.environment)}
    ..removeWhere((_, value) => value.isEmpty);
}
