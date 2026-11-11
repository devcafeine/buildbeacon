// BuildBeacon Hub — Tests SDK : validation des réglages et conformité.
// Version 1.1 (2026-11-11) — messages traduits ; conformité en anglais, traduction anglaise exigée.

import 'package:buildbeacon_plugin_sdk/buildbeacon_plugin_sdk.dart';
import 'package:test/test.dart';

/// Plugin bien écrit : la conformité ne doit rien lui reprocher.
final class _GoodPlugin extends SourcePlugin {
  const _GoodPlugin();

  @override
  String get type => 'printer_3d';

  @override
  LocalizedText get label =>
      const LocalizedText({'en': '3D printer', 'fr': 'Imprimante 3D'});

  @override
  LocalizedText get description => const LocalizedText({
    'en': 'Progress and temperatures of a print.',
    'fr': 'Avancement et températures d\'une impression.',
  });

  @override
  List<SettingField> get settings => const [
    SettingField(
      id: 'host',
      label: LocalizedText({'en': 'Address', 'fr': 'Adresse'}),
      required: true,
      pattern: r'[\w.-]+',
      patternHint: LocalizedText({'en': 'name or IP', 'fr': 'nom ou IP'}),
    ),
    SettingField(
      id: 'port',
      label: LocalizedText.same('Port'),
      kind: SettingKind.integer,
    ),
    SettingField(
      id: 'model',
      label: LocalizedText({'en': 'Model', 'fr': 'Modèle'}),
      kind: SettingKind.choice,
      choices: ['p1s', 'x1c'],
    ),
  ];

  @override
  List<SecretField> get secrets => const [
    SecretField(
      env: 'BB_PRINTER_CODE',
      label: LocalizedText({'en': 'Access code', 'fr': 'Code d\'accès'}),
    ),
  ];

  @override
  List<MetricInfo> get metrics => const [
    MetricInfo(
      id: 'progress',
      label: LocalizedText({'en': 'Progress', 'fr': 'Progression'}),
      min: 0,
      max: 100,
    ),
  ];

  @override
  List<LocalizedText> validateSettings(SourceSettings settings) => [
    if (settings.text('host') == 'localhost')
      const LocalizedText({
        'en': 'the printer cannot be the Hub itself',
        'fr': 'l\'imprimante ne peut pas être le Hub lui-même',
      }),
  ];

  @override
  Stream<SourceState> connect(SourceSettings settings, PluginContext context) =>
      const Stream.empty();
}

/// Plugin qui enfreint une règle de chaque sorte.
final class _BadPlugin extends SourcePlugin {
  const _BadPlugin();

  @override
  String get type => 'Bad-Type';

  @override
  LocalizedText get label => const LocalizedText({'fr': 'Mauvais'});

  @override
  LocalizedText get description => const LocalizedText.same('Badly written.');

  @override
  List<SettingField> get settings => const [
    SettingField(id: 'Repo', label: LocalizedText.same('Repository')),
    SettingField(
      id: 'mode',
      label: LocalizedText.same('Mode'),
      kind: SettingKind.choice,
    ),
    SettingField(id: 'mode', label: LocalizedText.same('Mode bis')),
    SettingField(
      id: 'filter',
      label: LocalizedText.same('Filter'),
      pattern: '[a-',
    ),
  ];

  @override
  List<SecretField> get secrets => const [
    SecretField(env: 'github_token', label: LocalizedText.same('Token')),
  ];

  @override
  List<MetricInfo> get metrics => const [
    MetricInfo(
      id: 'temp',
      label: LocalizedText.same('Temperature'),
      min: 10,
      max: 0,
    ),
  ];

  @override
  Stream<SourceState> connect(SourceSettings settings, PluginContext context) =>
      const Stream.empty();
}

void main() {
  const good = _GoodPlugin();

  group('réglages d\'une source', () {
    test('réglages corrects', () {
      expect(
        settingsIssues(good, {
          'host': 'bambu.local',
          'port': 8883,
          'model': 'p1s',
        }),
        isEmpty,
      );
    });

    test('obligatoire, format, type, choix et faute de frappe', () {
      expect(settingsIssues(good, {}).resolveAll('fr'), [
        '« Adresse » est obligatoire',
      ]);
      expect(
        settingsIssues(good, {
          'host': 'bambu local',
          'port': '8883',
          'model': 'a1',
          'prot': 1,
        }).resolveAll('fr'),
        [
          '« Adresse » invalide : « bambu local » (nom ou IP attendu)',
          '« Port » : un nombre entier attendu',
          '« Modèle » : « a1 » inconnu (p1s, x1c)',
          'réglage inconnu « prot » pour Imprimante 3D',
        ],
      );
    });

    test('les mêmes messages en anglais', () {
      expect(settingsIssues(good, {}).resolveAll('en'), [
        '"Address" is required',
      ]);
      expect(settingsIssues(good, {'host': 'a b'}).resolveAll('en'), [
        '"Address" is invalid: "a b" (expected: name or IP)',
      ]);
    });

    test('contrôle du plugin, seulement si les champs sont valides', () {
      expect(settingsIssues(good, {'host': 'localhost'}).resolveAll('fr'), [
        'l\'imprimante ne peut pas être le Hub lui-même',
      ]);
      expect(
        settingsIssues(good, {
          'host': 'localhost',
          'port': 'x',
        }).resolveAll('fr'),
        ['« Port » : un nombre entier attendu'],
      );
    });
  });

  group('conformité', () {
    test('plugin bien écrit : rien à redire', () {
      expect(conformanceIssues(good), isEmpty);
    });

    test('chaque règle enfreinte est signalée (en anglais)', () {
      expect(conformanceIssues(const _BadPlugin()), [
        'type "Bad-Type": lowercase letters, digits and _, '
            'starting with a letter',
        'label: English translation missing',
        'setting "mode" declared twice',
        'setting "Repo": lowercase letters, digits and _ '
            '(it is a config.json key)',
        'setting "mode": choice kind without choices',
        'setting "filter": invalid pattern "[a-"',
        'secret "github_token": uppercase variable name prefixed with BB_',
        'metric "temp": min (10.0) must be lower than max (0.0)',
      ]);
    });

    test('description JSON complète, textes dans chaque langue', () {
      final json = good.describe();
      expect(json['type'], 'printer_3d');
      expect(json['label'], {'en': '3D printer', 'fr': 'Imprimante 3D'});
      expect(json['secrets'], [
        {
          'env': 'BB_PRINTER_CODE',
          'label': {'en': 'Access code', 'fr': 'Code d\'accès'},
          'required': false,
        },
      ]);
      expect((json['settings']! as List<Object?>).first, {
        'id': 'host',
        'label': {'en': 'Address', 'fr': 'Adresse'},
        'kind': 'text',
        'required': true,
        'pattern': r'[\w.-]+',
        'pattern_hint': {'en': 'name or IP', 'fr': 'nom ou IP'},
      });
    });
  });
}
