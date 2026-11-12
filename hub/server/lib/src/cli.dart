// BuildBeacon Hub — Helpers shared by the command-line programs (bin/).
// Version 1.2 (2026-11-12) — comments in English.

import 'dart:io';

import 'package:buildbeacon_core/buildbeacon_core.dart';

/// Language of the command-line programs: `BB_LANG`, otherwise the system
/// language (`LC_ALL`, `LANG`, machine settings); English if it is not
/// translated.
String cliLanguage([Map<String, String>? environment]) {
  final env = environment ?? Platform.environment;
  final locale = [
    env['BB_LANG'],
    env['LC_ALL'],
    env['LANG'],
    if (environment == null) Platform.localeName,
  ].firstWhere((value) => value != null && value.isNotEmpty, orElse: () => '');
  return languageOf(locale);
}

/// Reads the `--name value` options ([withValue]) and the `--name` flags
/// ([flags]). `--help` (or `-h`) prints [usage]; an unknown option prints it
/// too and stops the program.
Map<String, String?> parseOptions(
  List<String> args, {
  required String usage,
  required String language,
  Set<String> withValue = const {},
  Set<String> flags = const {},
}) {
  final options = <String, String?>{};
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    final name = arg.startsWith('--') ? arg.substring(2) : null;
    if (name == 'help' || arg == '-h') {
      stdout.writeln(usage);
      exit(0);
    }
    if (name != null && withValue.contains(name) && i + 1 < args.length) {
      options[name] = args[++i];
    } else if (name != null && flags.contains(name)) {
      options[name] = null;
    } else {
      stderr.writeln(
        '${tr(language, en: 'Unknown or incomplete option', fr: 'Option inconnue ou incomplète')}'
        ' : $arg\n\n$usage',
      );
      exit(64);
    }
  }
  return options;
}

/// Integer option [name], or [orElse] if it is missing.
int intOption(
  Map<String, String?> options,
  String name,
  int orElse, {
  required String usage,
  required String language,
}) {
  final text = options[name];
  if (text == null) return orElse;
  return int.tryParse(text) ??
      fail(
        '${tr(language, en: '--$name expects an integer, not "$text".', fr: '--$name attend un nombre entier, pas « $text ».')}'
        '\n\n$usage',
      );
}

/// Stops the program with an error message.
Never fail(String message) {
  stderr.writeln(message);
  exit(1);
}

/// Duration in seconds: "2.5 s" in English, "2,5 s" in French.
String formatSeconds(Duration duration, String language) {
  final text = (duration.inMilliseconds / 1000).toStringAsFixed(1);
  return '${language == 'fr' ? text.replaceAll('.', ',') : text} s';
}
