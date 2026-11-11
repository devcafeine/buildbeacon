// BuildBeacon Hub — Tests : le Hub assemblé (config → plugins → image → sortie, WLED).
// Version 1.0 (2026-11-11)

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:buildbeacon_core/buildbeacon_core.dart';
import 'package:buildbeacon_hub/buildbeacon_hub.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// Plugin alimenté à la main par le test.
final class _ManualPlugin extends SourcePlugin {
  final controllers = <String, StreamController<SourceState>>{};

  @override
  String get type => 'manual';

  @override
  LocalizedText get label => const LocalizedText.same('Manual');

  @override
  LocalizedText get description => const LocalizedText.same('Test plugin.');

  @override
  List<SettingField> get settings => const [
    SettingField(id: 'name', label: LocalizedText.same('Name'), required: true),
  ];

  @override
  bool get providesHistory => true;

  @override
  Stream<SourceState> connect(SourceSettings settings, PluginContext context) {
    final controller = StreamController<SourceState>();
    controllers[settings.text('name')] = controller;
    return controller.stream;
  }
}

/// Sortie de test : garde les images envoyées et les adresses ouvertes.
final class _Outputs {
  final opened = <String>[];
  final closed = <String>[];
  final frames = <Uint8List>[];

  Future<LedOutputHandle> open(
    WledConfig wled,
    void Function(LocalizedText message) log,
  ) async {
    final address = '${wled.host}:${wled.ddpPort}';
    opened.add(address);
    return (
      sink: _RecordingSink(frames),
      close: () async => closed.add(address),
    );
  }
}

final class _RecordingSink implements LedSink {
  _RecordingSink(this.frames);

  final List<Uint8List> frames;

  @override
  void send(Uint8List rgb) => frames.add(rgb);
}

SourceConfig _manual(String name) =>
    SourceConfig(type: 'manual', settings: {'name': name});

Config _config(
  String source, {
  String host = '127.0.0.1',
  int brightness = 128,
}) => Config(
  wled: WledConfig(host: host, brightness: brightness),
  tiles: [
    Tile(
      id: 'master',
      label: 'BuildBeacon',
      kind: TileKind.master,
      chainIndex: 0,
      pos: const HexPos(0, 1),
    ),
    Tile(
      id: 'app',
      label: 'App',
      kind: TileKind.project,
      chainIndex: 1,
      pos: const HexPos(0, 0),
      zones: {
        ZoneName.ambient: ZoneAction(
          source: _manual(source),
          mode: DisplayMode.overall,
        ),
      },
    ),
  ],
);

/// Faux WLED : `/json/info` annonce [ledCount] LED, `/json/state` mémorise
/// la luminosité ; `null` = WLED injoignable.
MockClient _wled({int? ledCount = 12, List<int>? brightness}) =>
    MockClient((request) async {
      if (ledCount == null) throw http.ClientException('connection refused');
      if (request.url.path == '/json/info') {
        return http.Response(
          jsonEncode({
            'ver': '0.15.0',
            'name': 'WLED',
            'leds': {'count': ledCount},
          }),
          200,
        );
      }
      brightness?.add(
        (jsonDecode(request.body) as Map<String, Object?>)['bri']! as int,
      );
      return http.Response('{"success":true}', 200);
    });

void main() {
  late _ManualPlugin plugin;
  late _Outputs outputs;
  late List<String> logs;

  setUp(() {
    plugin = _ManualPlugin();
    outputs = _Outputs();
    logs = [];
  });

  Hub hub(http.Client client) => Hub(
    plugins: PluginRegistry([plugin]),
    httpClient: client,
    openOutput: outputs.open,
    log: (message) => logs.add(message.resolve('fr')),
  );

  test('les états des plugins arrivent jusqu\'aux LED', () async {
    final h = hub(_wled());
    await h.start(_config('a'));
    addTearDown(h.stop);

    plugin.controllers['a']!.add(const SourceState(history: [Status.failure]));
    await Future<void>.delayed(const Duration(milliseconds: 150));

    final last = outputs.frames.last;
    expect(last, hasLength(12 * 3));
    // Ambiance de la tuile n° 1 (LED 3) en rouge.
    expect(last.sublist(9, 12), [255, 0, 0]);
    expect(logs, contains(startsWith('manual · a — échec')));
  });

  test('WLED vérifié : nombre de LED, luminosité réglée', () async {
    final brightness = <int>[];
    final h = hub(_wled(ledCount: 12, brightness: brightness));
    await h.start(_config('a', brightness: 90));
    addTearDown(h.stop);

    expect(logs, contains('WLED 0.15.0 « WLED » : 12 LED'));
    expect(logs, contains('Luminosité WLED : 90/255'));
    expect(brightness, [90]);
  });

  test('WLED réglé sur un autre nombre de LED : signalé', () async {
    final h = hub(_wled(ledCount: 30));
    await h.start(_config('a'));
    addTearDown(h.stop);

    expect(
      logs,
      contains(allOf(contains('réglé sur 30 LED'), contains('en décrit 12'))),
    );
  });

  test(
    'API JSON injoignable (simulateur) : signalée, les images partent quand même',
    () async {
      final h = hub(_wled(ledCount: null));
      await h.start(_config('a'));
      addTearDown(h.stop);
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(logs, contains(contains('API JSON de WLED injoignable')));
      expect(outputs.frames, isNotEmpty);
    },
  );

  test('nouvelle config : nouvelle source ouverte, ancienne fermée', () async {
    final h = hub(_wled());
    await h.start(_config('a'));
    addTearDown(h.stop);
    final first = plugin.controllers['a']!;

    await h.apply(_config('b'));

    expect(first.hasListener, isFalse);
    expect(plugin.controllers['b']!.hasListener, isTrue);
    expect(outputs.opened, ['127.0.0.1:4048']);
  });

  test('nouvelle adresse WLED : sortie rouverte', () async {
    final h = hub(_wled());
    await h.start(_config('a'));
    addTearDown(h.stop);

    await h.apply(_config('a', host: '192.168.1.50'));

    expect(outputs.opened, ['127.0.0.1:4048', '192.168.1.50:4048']);
    expect(outputs.closed, ['127.0.0.1:4048']);
  });

  test('un état inchangé n\'est journalisé qu\'une fois', () async {
    final h = hub(_wled());
    await h.start(_config('a'));
    addTearDown(h.stop);
    final controller = plugin.controllers['a']!;

    for (var i = 0; i < 3; i++) {
      controller.add(const SourceState(history: [Status.success]));
    }
    await pumpEventQueue();

    expect(logs.where((line) => line.startsWith('manual · a')), hasLength(1));
  });

  test('arrêt : sources et sortie fermées', () async {
    final h = hub(_wled());
    await h.start(_config('a'));
    await h.stop();

    expect(plugin.controllers['a']!.hasListener, isFalse);
    expect(outputs.closed, ['127.0.0.1:4048']);
  });

  group('quota GitHub sans jeton', () {
    Config github(int sources, int pollSeconds) => Config(
      pollSeconds: pollSeconds,
      tiles: [
        for (var i = 0; i < sources; i++)
          Tile(
            id: 't$i',
            label: '',
            kind: TileKind.project,
            chainIndex: i + 1,
            pos: HexPos(i, 0),
            zones: {
              ZoneName.ambient: ZoneAction(
                source: SourceConfig(
                  type: 'github',
                  settings: {'repo': 'acme/r$i'},
                ),
                mode: DisplayMode.overall,
              ),
            },
          ),
      ],
    );

    test('3 sources toutes les 30 s : 360 requêtes/h, 180 s au moins', () {
      final warning = githubQuotaWarning(github(3, 30), const {});
      expect(
        warning?.resolve('fr'),
        allOf(contains('en demandent 360'), contains('à 180 au moins')),
      );
    });

    test('dans le quota, ou avec un jeton : rien à signaler', () {
      expect(githubQuotaWarning(github(3, 180), const {}), isNull);
      expect(
        githubQuotaWarning(github(3, 30), const {'BB_GITHUB_TOKEN': 'x'}),
        isNull,
      );
    });
  });

  test('résumés lisibles d\'une source et d\'un état', () {
    expect(
      describeSource(
        SourceConfig(
          type: 'github',
          settings: {'repo': 'acme/app', 'workflow': 'ci.yml'},
        ),
      ),
      'github · acme/app · ci.yml',
    );
    const state = SourceState(
      status: Status.running,
      metrics: {'progress': Metric(62.5, unit: '%')},
    );
    expect(describeState(state, 'fr'), 'en cours · progress 62.5 %');
    expect(describeState(state, 'en'), 'running · progress 62.5 %');
  });
}
