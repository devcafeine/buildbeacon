// BuildBeacon Hub — Tests: plugin contract, registry and validation.
// Version 1.4 (2026-11-12) — test names in English.

import 'package:buildbeacon_core/buildbeacon_core.dart';
import 'package:test/test.dart';

/// Test plugin, fully described by its constructor.
final class _TestPlugin extends SourcePlugin {
  const _TestPlugin({
    required this.type,
    this.settings = const [],
    this.secrets = const [],
    this.providesHistory = false,
    this.metrics = const [],
    this.dynamicMetrics = false,
    this.check,
  });

  @override
  final String type;

  @override
  LocalizedText get label => LocalizedText.same('Plugin $type');

  @override
  LocalizedText get description => const LocalizedText.same('Test plugin.');

  @override
  final List<SettingField> settings;

  @override
  final List<SecretField> secrets;

  @override
  final bool providesHistory;

  @override
  final List<MetricInfo> metrics;

  @override
  final bool dynamicMetrics;

  final List<LocalizedText> Function(SourceSettings settings)? check;

  @override
  List<LocalizedText> validateSettings(SourceSettings settings) =>
      check?.call(settings) ?? const [];

  @override
  Stream<SourceState> connect(SourceSettings settings, PluginContext context) =>
      const Stream.empty();
}

List<LocalizedText> _notTheHub(SourceSettings settings) => [
  if (settings.text('host') == 'localhost')
    const LocalizedText({
      'en': 'the printer cannot be the Hub itself',
      'fr': 'l\'imprimante ne peut pas être le Hub lui-même',
    }),
];

/// Like a CI plugin: a history, no measurement.
const _ci = _TestPlugin(
  type: 'ci',
  providesHistory: true,
  settings: [
    SettingField(
      id: 'project',
      label: LocalizedText({'en': 'Project', 'fr': 'Projet'}),
      required: true,
      pattern: '[a-z]+/[a-z]+',
      patternHint: LocalizedText({
        'en': 'group/project',
        'fr': 'groupe/projet',
      }),
    ),
    SettingField(
      id: 'environment',
      label: LocalizedText({'en': 'Environment', 'fr': 'Environnement'}),
      kind: SettingKind.choice,
      choices: ['prod', 'staging'],
    ),
    SettingField(
      id: 'limit',
      label: LocalizedText({'en': 'Limit', 'fr': 'Limite'}),
      kind: SettingKind.integer,
    ),
  ],
);

/// Like a 3D printer: measurements, no history.
const _printer = _TestPlugin(
  type: 'printer',
  settings: [
    SettingField(
      id: 'host',
      label: LocalizedText({'en': 'Address', 'fr': 'Adresse'}),
      required: true,
    ),
  ],
  secrets: [
    SecretField(
      env: 'BB_PRINTER_CODE',
      label: LocalizedText({'en': 'Access code', 'fr': 'Code d\'accès'}),
      required: true,
    ),
  ],
  metrics: [
    MetricInfo(
      id: 'progress',
      label: LocalizedText({'en': 'Progress', 'fr': 'Progression'}),
      unit: '%',
      min: 0,
      max: 100,
    ),
    MetricInfo(
      id: 'nozzle_temp',
      label: LocalizedText({'en': 'Nozzle', 'fr': 'Buse'}),
      unit: '°C',
    ),
  ],
  check: _notTheHub,
);

/// Like a generic (JSON) plugin: measurements named by the user.
const _generic = _TestPlugin(
  type: 'http_json',
  providesHistory: true,
  dynamicMetrics: true,
  settings: [
    SettingField(id: 'url', label: LocalizedText.same('URL'), required: true),
  ],
);

final _registry = PluginRegistry(const [_ci, _printer, _generic]);

SourceConfig _source(String type, Map<String, Object?> settings) =>
    SourceConfig(type: type, settings: settings);

final _okCi = _source('ci', {'project': 'acme/app'});
final _okPrinter = _source('printer', {'host': 'bambu.local'});

ZoneAction _action(SourceConfig source, DisplayMode mode, {String? metric}) =>
    ZoneAction(
      source: source,
      mode: mode,
      metric: metric,
      thresholds: const Thresholds(failure: 1),
    );

void main() {
  group('registry', () {
    test('finds a plugin by its type', () {
      expect(_registry['ci'], same(_ci));
      expect(_registry['gitlab'], isNull);
      expect(_registry.all.map((p) => p.type), ['ci', 'printer', 'http_json']);
    });

    test('rejects two plugins of the same type', () {
      expect(() => PluginRegistry(const [_ci, _ci]), throwsArgumentError);
    });

    test('rejects an invalid type id', () {
      expect(
        () => PluginRegistry(const [_TestPlugin(type: 'Git-Hub')]),
        throwsArgumentError,
      );
    });

    test('the "type" setting is reserved', () {
      expect(
        () => PluginRegistry(const [
          _TestPlugin(
            type: 'x',
            settings: [
              SettingField(id: 'type', label: LocalizedText.same('Type')),
            ],
          ),
        ]),
        throwsArgumentError,
      );
    });
  });

  group('source settings', () {
    test('valid settings', () {
      expect(
        _registry.validateSource(
          _source('ci', {
            'project': 'acme/app',
            'environment': 'prod',
            'limit': 5,
          }),
        ),
        isEmpty,
      );
    });

    test('unknown type: available types are listed', () {
      expect(_registry.validateSource(_source('gitlab', {})).resolveAll('fr'), [
        allOf(contains('« gitlab »'), contains('ci, printer, http_json')),
      ]);
    });

    test('missing required setting', () {
      expect(_registry.validateSource(_source('ci', {})).resolveAll('fr'), [
        '« Projet » est obligatoire',
      ]);
    });

    test('format, choice and value type', () {
      expect(
        _registry
            .validateSource(
              _source('ci', {
                'project': 'Acme',
                'environment': 'dev',
                'limit': '5',
              }),
            )
            .resolveAll('fr'),
        [
          '« Projet » invalide : « Acme » (groupe/projet attendu)',
          '« Environnement » : « dev » inconnu (prod, staging)',
          '« Limite » : un nombre entier attendu',
        ],
      );
    });

    test('unknown setting (typo)', () {
      expect(
        _registry
            .validateSource(
              _source('ci', {'project': 'acme/app', 'projct': 'x'}),
            )
            .resolveAll('fr'),
        ['réglage inconnu « projct » pour Plugin ci'],
      );
    });

    test('plugin-specific check', () {
      expect(
        _registry
            .validateSource(_source('printer', {'host': 'localhost'}))
            .resolveAll('fr'),
        [contains('ne peut pas être le Hub')],
      );
    });
  });

  group('display mode depending on what the plugin provides', () {
    test('history: only if the plugin provides one', () {
      expect(
        _registry.validateAction(_action(_okCi, DisplayMode.history)),
        isEmpty,
      );
      expect(
        _registry
            .validateAction(_action(_okPrinter, DisplayMode.history))
            .resolveAll('fr'),
        [contains('ne fournit pas d\'historique')],
      );
    });

    test('thresholds and gauge: only with metrics', () {
      expect(
        _registry.validateAction(
          _action(_okPrinter, DisplayMode.gauge, metric: 'progress'),
        ),
        isEmpty,
      );
      expect(
        _registry
            .validateAction(_action(_okCi, DisplayMode.gauge))
            .resolveAll('fr'),
        [contains('ne fournit pas de mesure')],
      );
    });

    test('unknown metric: available metrics are listed', () {
      expect(
        _registry
            .validateAction(
              _action(_okPrinter, DisplayMode.thresholds, metric: 'humidity'),
            )
            .resolveAll('fr'),
        [
          allOf(
            contains('« humidity » inconnue'),
            contains('progress, nozzle_temp'),
          ),
        ],
      );
    });

    test('generic plugin: any metric is accepted', () {
      final source = _source('http_json', {
        'url': 'http://workshop.local/state',
      });
      expect(
        _registry.validateAction(
          _action(source, DisplayMode.gauge, metric: 'fill_level'),
        ),
        isEmpty,
      );
    });
  });

  group('config validation', () {
    final config = Config(
      tiles: [
        Tile(
          id: 'master',
          label: 'BuildBeacon',
          kind: TileKind.master,
          chainIndex: 0,
          pos: const HexPos(0, 1),
        ),
        Tile(
          id: 'bambu',
          label: 'Bambu',
          kind: TileKind.project,
          chainIndex: 1,
          pos: const HexPos(0, 0),
          zones: {
            ZoneName.dots: ZoneAction(
              source: _okPrinter,
              mode: DisplayMode.history,
            ),
          },
        ),
      ],
    );

    test('with the registry: issue attached to the tile and zone', () {
      expect(config.validate(plugins: _registry).resolveAll('fr'), [
        'Tuile « Bambu » : points : Plugin printer ne fournit pas '
            'd\'historique : mode « historique » impossible',
      ]);
      expect(config.validate(plugins: _registry).resolveAll('en'), [
        'Tile "Bambu": dots: Plugin printer provides no history: '
            '"history" mode unavailable',
      ]);
    });

    test('without a registry: sources not checked', () {
      expect(config.validate(), isEmpty);
    });
  });

  test('description for the UI, texts in each language', () {
    final json = _printer.describe();
    expect(json['type'], 'printer');
    expect(json['provides_history'], isFalse);
    expect(json['settings'], [
      {
        'id': 'host',
        'label': {'en': 'Address', 'fr': 'Adresse'},
        'kind': 'text',
        'required': true,
      },
    ]);
    expect(json['secrets'], [
      {
        'env': 'BB_PRINTER_CODE',
        'label': {'en': 'Access code', 'fr': 'Code d\'accès'},
        'required': true,
      },
    ]);
    expect(
      (json['metrics']! as List<Object?>).map(
        (m) => (m! as Map<String, Object?>)['id'],
      ),
      ['progress', 'nozzle_temp'],
    );
  });
}
