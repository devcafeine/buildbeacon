// BuildBeacon Hub — Reading and writing config.json.
// Version 1.4 (2026-11-12) — comments in English.

import 'dart:convert';
import 'dart:io';

import 'package:buildbeacon_core/buildbeacon_core.dart';

/// Reads the configuration from the file [path]. Throws a
/// [LocalizedFormatException] whose message names the file (missing, invalid
/// JSON, rejected content).
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

/// Configuration from the file [path]; if it does not exist (first start),
/// it is created with the starting configuration, the master tile only
/// ([Config.initial]), to be set up afterwards from the web interface.
///
/// An existing but unreadable or rejected file is never replaced: same error
/// as [readConfigFile]. A folder that cannot be created throws a
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

/// Saves [config] to [path] atomically: writes a temporary file next to it,
/// then renames it. An abrupt stop during the write leaves the old file
/// intact.
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
