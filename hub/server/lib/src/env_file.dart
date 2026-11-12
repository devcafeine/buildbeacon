// BuildBeacon Hub — Reading a .env file (environment variables).
// Version 1.1 (2026-11-12) — comments in English.

import 'dart:io';

final _validKey = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$');

/// Reads the content of a `.env` file: `NAME=value` lines, `#` comments,
/// optional quotes around the value, `export ` prefix accepted. Unreadable
/// lines are ignored.
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

/// Environment of the Hub: the variables of the file [envFile] if it exists,
/// then those of the process, which take precedence. Empty values are
/// ignored (a `.env` copied from `.env.example` without being filled in).
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
