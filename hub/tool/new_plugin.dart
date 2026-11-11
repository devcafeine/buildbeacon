// BuildBeacon Hub — Crée un plugin de source à partir du modèle.
// Version 1.1 (2026-11-11) — ex nouveau_plugin.dart : nom et option en anglais (--root), messages traduits, modèle avec textes traduits.
//
// Depuis la racine du dépôt : mise run new-plugin <name>
// Depuis hub/ :               dart run tool/new_plugin.dart <name> [--root <hub folder>]
//
// Crée hub/plugins/<name>/ (plugin d'exemple qui fonctionne, tests, README),
// l'inscrit dans l'espace de travail, les dépendances du serveur et la liste
// des plugins intégrés, puis lance `dart pub get` et `dart format`.

import 'dart:io';

final _validName = RegExp(r'^[a-z][a-z0-9_]*$');
final _versionLine = RegExp(
  r'^(#|//) Version( du fichier :)? (\d+)\.(\d+) \(\d{4}-\d{2}-\d{2}\).*$',
  multiLine: true,
);

/// Langue des messages : `BB_LANG`, sinon la langue du système ; anglais par
/// défaut. (Ce script n'a pas de dépendance : il ne peut pas utiliser le SDK.)
final String _lang = () {
  final env = Platform.environment;
  final locale = [
    env['BB_LANG'],
    env['LC_ALL'],
    env['LANG'],
    Platform.localeName,
  ].firstWhere((v) => v != null && v.isNotEmpty, orElse: () => '')!;
  return locale.toLowerCase().startsWith('fr') ? 'fr' : 'en';
}();

String _tr({required String en, required String fr}) => _lang == 'fr' ? fr : en;

Future<void> main(List<String> args) async {
  final (name, root) = _parseArgs(args);
  final today = DateTime.now().toIso8601String().substring(0, 10);
  final className =
      '${name.split('_').map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1)).join()}Plugin';
  final label = name.replaceAll('_', ' ');
  final tokens = {
    '%NAME%': name,
    '%CLASS%': className,
    '%LABEL%': label[0].toUpperCase() + label.substring(1),
    '%DATE%': today,
    '%ENV%': 'BB_${name.toUpperCase()}',
  };
  String fill(String template) =>
      tokens.entries.fold(template, (t, e) => t.replaceAll(e.key, e.value));

  final dir = Directory('$root/plugins/$name');
  if (dir.existsSync()) {
    _fail(
      _tr(
        en: 'The folder ${dir.path} already exists.',
        fr: 'Le dossier ${dir.path} existe déjà.',
      ),
    );
  }
  for (final file in ['pubspec.yaml', 'server/pubspec.yaml']) {
    if (!File('$root/$file').existsSync()) {
      _fail(
        _tr(
          en: '$root does not look like the hub/ folder ($file not found).',
          fr: '$root ne ressemble pas au dossier hub/ ($file introuvable).',
        ),
      );
    }
  }

  // 1. Le paquet du plugin.
  final files = {
    'pubspec.yaml': _pubspec,
    'README.md': _lang == 'fr' ? _readmeFr : _readmeEn,
    'lib/buildbeacon_plugin_$name.dart': _library,
    'lib/src/${name}_plugin.dart': _plugin,
    'test/${name}_plugin_test.dart': _test,
  };
  for (final MapEntry(key: path, value: template) in files.entries) {
    File('${dir.path}/$path')
      ..createSync(recursive: true)
      ..writeAsStringSync(fill(template));
  }

  // 2. Son inscription dans le Hub.
  final note = 'plugin $name ajouté';
  _insertAbove(File('$root/pubspec.yaml'), today, note, {
    'new-plugin: plugins are added above': (indent) =>
        '$indent- plugins/$name\n',
  });
  _insertAbove(File('$root/server/pubspec.yaml'), today, note, {
    'new-plugin: dependencies are added above': (indent) =>
        '${indent}buildbeacon_plugin_$name:\n$indent  path: ../plugins/$name\n',
  });
  _insertAbove(File('$root/server/lib/src/builtin_plugins.dart'), today, note, {
    'new-plugin: imports are added above': (indent) =>
        "${indent}import 'package:buildbeacon_plugin_$name/buildbeacon_plugin_$name.dart';\n",
    'new-plugin: plugins are added above': (indent) => '$indent$className(),\n',
  });

  // 3. Dépendances et mise en forme.
  await _run(root, ['pub', 'get']);
  await _run(root, [
    'format',
    'plugins/$name',
    'server/lib/src/builtin_plugins.dart',
  ]);

  stdout.writeln(
    _tr(
      en:
          '''

Plugin "$name" created in ${dir.path} and registered in the Hub.

Next steps:
  1. Write how the source is read: plugins/$name/lib/src/${name}_plugin.dart
     (the template polls a URL: success if it answers, failure otherwise).
  2. Adapt the tests: plugins/$name/test/${name}_plugin_test.dart
  3. Check: mise run check
SDK guide: sdk/README.md''',
      fr:
          '''

Plugin « $name » créé dans ${dir.path} et inscrit dans le Hub.

Prochaines étapes :
  1. Écrire la lecture de la source : plugins/$name/lib/src/${name}_plugin.dart
     (le modèle interroge une URL : succès si elle répond, échec sinon).
  2. Adapter les tests : plugins/$name/test/${name}_plugin_test.dart
  3. Vérifier : mise run check
Guide du SDK : sdk/README.md''',
    ),
  );
}

(String, String) _parseArgs(List<String> args) {
  String? name;
  var root = '.';
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--root' && i + 1 < args.length) {
      root = args[++i];
    } else if (name == null && !args[i].startsWith('-')) {
      name = args[i];
    } else {
      _fail(
        _tr(
          en: 'Unexpected argument: ${args[i]}',
          fr: 'Argument inattendu : ${args[i]}',
        ),
      );
    }
  }
  if (name == null) {
    _fail(
      _tr(
        en: 'Usage: mise run new-plugin <name>   (e.g. ping_http, bambu)',
        fr: 'Usage : mise run new-plugin <nom>   (ex. : ping_http, bambu)',
      ),
    );
  }
  if (!_validName.hasMatch(name)) {
    _fail(
      _tr(
        en:
            'Invalid name "$name": lowercase letters, digits and _, starting '
            'with a letter. It becomes the plugin type in config.json.',
        fr:
            'Nom « $name » invalide : minuscules, chiffres et _, en commençant '
            'par une lettre. Il devient le type du plugin dans config.json.',
      ),
    );
  }
  return (name, root);
}

/// Insère, au-dessus de chaque repère, la ligne produite par sa fonction
/// (qui reçoit l'indentation du repère), puis incrémente la version du
/// fichier (règle du projet : une version par modification).
void _insertAbove(
  File file,
  String today,
  String note,
  Map<String, String Function(String indent)> inserts,
) {
  var content = file.readAsStringSync();
  for (final MapEntry(key: marker, value: line) in inserts.entries) {
    final index = content.indexOf(marker);
    if (index < 0) {
      _fail(
        _tr(
          en: 'Marker "$marker" not found in ${file.path}.',
          fr: 'Repère « $marker » introuvable dans ${file.path}.',
        ),
      );
    }
    final lineStart = content.lastIndexOf('\n', index) + 1;
    final indent = RegExp(
      r'^[ \t]*',
    ).stringMatch(content.substring(lineStart))!;
    content =
        content.substring(0, lineStart) +
        line(indent) +
        content.substring(lineStart);
  }

  final version = _versionLine.firstMatch(content);
  if (version == null) {
    _fail(
      _tr(
        en: 'Version line not found in ${file.path}.',
        fr: 'Ligne de version introuvable dans ${file.path}.',
      ),
    );
  }
  final minor = int.parse(version[4]!) + 1;
  content = content.replaceRange(
    version.start,
    version.end,
    '${version[1]} Version${version[2] ?? ''} ${version[3]}.$minor ($today) — $note.',
  );
  file.writeAsStringSync(content);
  stdout.writeln(
    _tr(
      en: '${file.path}: registered, version ${version[3]}.$minor',
      fr: '${file.path} : inscrit, version ${version[3]}.$minor',
    ),
  );
}

Future<void> _run(String root, List<String> args) async {
  final result = await Process.run('dart', args, workingDirectory: root);
  if (result.exitCode != 0) {
    stderr
      ..write(result.stdout)
      ..write(result.stderr);
    _fail(
      _tr(
        en: '"dart ${args.join(' ')}" failed.',
        fr: 'Échec de « dart ${args.join(' ')} ».',
      ),
    );
  }
}

Never _fail(String message) {
  stderr.writeln(message);
  exit(64);
}

// ---------------------------------------------------------------------------
// Modèles. Jetons remplacés : %NAME%, %CLASS%, %LABEL%, %DATE%, %ENV%.

const _pubspec = r'''
# BuildBeacon Hub — plugin %LABEL%.
# Version du fichier : 1.0 (%DATE%)
name: buildbeacon_plugin_%NAME%
description: BuildBeacon plugin — %LABEL%.
version: 0.1.0
publish_to: none
resolution: workspace

environment:
  sdk: ^3.9.0

dependencies:
  buildbeacon_plugin_sdk:
    path: ../../sdk
  http: ^1.2.0

dev_dependencies:
  lints: ^6.0.0
  test: ^1.26.0
''';

const _library = r'''
// BuildBeacon Hub — Plugin %LABEL% : API publique du paquet.
// Version 1.0 (%DATE%)

/// BuildBeacon plugin "%LABEL%".
library;

export 'src/%NAME%_plugin.dart';
''';

const _plugin = r'''
// BuildBeacon Hub — Plugin %LABEL%.
// Version 1.0 (%DATE%)

import 'package:buildbeacon_plugin_sdk/buildbeacon_plugin_sdk.dart';

/// TODO: say in one sentence what this plugin watches.
///
/// Working starting point: polls a URL and shows success if it answers
/// (HTTP code < 400), failure otherwise. Replace [_read] with how your
/// source is read, then adjust the settings and the tests.
///
/// Texts shown to users are [LocalizedText]: give at least English ('en'),
/// French ('fr') is welcome.
final class %CLASS% extends SourcePlugin {
  const %CLASS%();

  @override
  String get type => '%NAME%';

  @override
  LocalizedText get label => const LocalizedText.same('%LABEL%');

  @override
  LocalizedText get description => const LocalizedText({
    'en': 'TODO: one sentence shown in the interface.',
    'fr': 'TODO : une phrase affichée dans l\'interface.',
  });

  @override
  List<SettingField> get settings => const [
    SettingField(
      id: 'url',
      label: LocalizedText.same('URL'),
      required: true,
      placeholder: 'https://example.com/health',
      pattern: r'https?://\S+',
      patternHint: LocalizedText.same('http(s)://…'),
    ),
  ];

  // Secrets (token, access code): read from the environment, never from
  // config.json. The plugin only receives the ones it declares.
  // @override
  // List<SecretField> get secrets => const [
  //   SecretField(env: '%ENV%_TOKEN', label: LocalizedText({'en': 'Token', 'fr': 'Jeton'})),
  // ];

  // What the plugin provides, so the right display modes are offered:
  // a history (history mode) and/or measurements (thresholds, gauge).
  // @override
  // bool get providesHistory => true;
  // @override
  // List<MetricInfo> get metrics => const [
  //   MetricInfo(id: 'progress', label: LocalizedText({'en': 'Progress', 'fr': 'Progression'}), unit: '%', min: 0, max: 100),
  // ];

  @override
  Stream<SourceState> connect(SourceSettings settings, PluginContext context) =>
      pollingStream(context.pollInterval, (_) => _read(settings, context));

  /// One read of the source. Throwing a [SourceException] shows its
  /// (translated) message in the interface; the panel keeps the last known
  /// state.
  Future<SourceState> _read(SourceSettings settings, PluginContext context) async {
    final url = Uri.parse(settings.text('url'));
    final response = await context.httpClient.get(url);
    return SourceState(
      status: response.statusCode < 400 ? Status.success : Status.failure,
      updatedAt: context.now(),
    );
  }
}
''';

const _test = r'''
// BuildBeacon Hub — Tests : plugin %LABEL%.
// Version 1.0 (%DATE%)

import 'package:buildbeacon_plugin_%NAME%/buildbeacon_plugin_%NAME%.dart';
import 'package:buildbeacon_plugin_sdk/buildbeacon_plugin_sdk.dart';
import 'package:buildbeacon_plugin_sdk/testing.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

void main() {
  const plugin = %CLASS%();
  const settings = {'url': 'https://example.com/health'};

  test('follows the Hub rules', () {
    expect(conformanceIssues(plugin), isEmpty);
  });

  test('settings: URL required and well formed', () {
    expect(settingsIssues(plugin, {}).resolveAll('en'), ['"URL" is required']);
    expect(settingsIssues(plugin, {'url': 'example.com'}).resolveAll('en'), [
      contains('expected: http(s)://…'),
    ]);
  });

  test('the service answers: success', () async {
    final state = await firstState(
      plugin,
      settings,
      context: fakeContext(respond: (_) => http.Response('ok', 200)),
    );
    expect(state.status, Status.success);
  });

  test('the service is down: failure', () async {
    final state = await firstState(
      plugin,
      settings,
      context: fakeContext(respond: (_) => http.Response('', 503)),
    );
    expect(state.status, Status.failure);
  });
}
''';

const _readmeEn = r'''
<!-- BuildBeacon Hub — plugin %LABEL%. Version 1.0 (%DATE%) -->
# %LABEL% plugin

TODO: what this plugin watches, and for whom.

## Settings

| Setting | Required | Description |
|---|---|---|
| `url` | yes | Address polled at each refresh. |

## Example in `config.json`

```json
{ "source": { "type": "%NAME%", "url": "https://example.com/health" }, "mode": "overall" }
```

## Development

- Code: `lib/src/%NAME%_plugin.dart`
- Tests: `mise run test` at the repository root
- SDK guide: `hub/sdk/README.md`
''';

const _readmeFr = r'''
<!-- BuildBeacon Hub — plugin %LABEL%. Version 1.0 (%DATE%) -->
# Plugin %LABEL%

TODO : ce que surveille ce plugin, et pour qui.

## Réglages

| Réglage | Obligatoire | Description |
|---|---|---|
| `url` | oui | Adresse interrogée à chaque scrutation. |

## Exemple dans `config.json`

```json
{ "source": { "type": "%NAME%", "url": "https://example.com/health" }, "mode": "overall" }
```

## Développement

- Code : `lib/src/%NAME%_plugin.dart`
- Tests : `mise run test` à la racine du dépôt
- Guide du SDK : `hub/sdk/README.md`
''';
