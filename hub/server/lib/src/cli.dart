// BuildBeacon Hub — Outils communs aux programmes en ligne de commande (bin/).
// Version 1.1 (2026-11-11) — langue de l'interface (BB_LANG ou système), messages traduits, options en anglais.

import 'dart:io';

import 'package:buildbeacon_core/buildbeacon_core.dart';

/// Langue des programmes en ligne de commande : `BB_LANG`, sinon la langue
/// du système (`LC_ALL`, `LANG`, réglages de la machine) ; anglais si elle
/// n'est pas traduite.
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

/// Lit les options `--name value` ([withValue]) et les drapeaux `--name`
/// ([flags]). `--help` (ou `-h`) affiche [usage] ; une option inconnue
/// l'affiche aussi et arrête le programme.
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

/// Option entière [name], ou [orElse] si elle est absente.
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

/// Arrête le programme avec un message d'erreur.
Never fail(String message) {
  stderr.writeln(message);
  exit(1);
}

/// Durée en secondes : « 2.5 s » en anglais, « 2,5 s » en français.
String formatSeconds(Duration duration, String language) {
  final text = (duration.inMilliseconds / 1000).toStringAsFixed(1);
  return '${language == 'fr' ? text.replaceAll('.', ',') : text} s';
}
