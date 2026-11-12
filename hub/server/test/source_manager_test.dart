// BuildBeacon Hub — Tests: running plugins and the source cache.
// Version 1.3 (2026-11-12) — comments in English.

import 'dart:async';
import 'dart:convert';

import 'package:buildbeacon_core/buildbeacon_core.dart';
import 'package:buildbeacon_hub/buildbeacon_hub.dart';
import 'package:buildbeacon_plugin_github/buildbeacon_plugin_github.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

typedef _Connection = ({
  SourceSettings settings,
  PluginContext context,
  StreamController<SourceState> controller,
});

/// Plugin defined outside the core, as a community plugin would be.
/// Each connection is a stream that the test feeds by hand.
final class _ManualPlugin extends SourcePlugin {
  _ManualPlugin({this.secretRequired = false});

  final bool secretRequired;
  final connections = <_Connection>[];

  @override
  String get type => 'manual';

  @override
  LocalizedText get label =>
      const LocalizedText({'en': 'Manual', 'fr': 'Manuel'});

  @override
  LocalizedText get description =>
      const LocalizedText.same('Test plugin fed by hand.');

  @override
  List<SettingField> get settings => const [
    SettingField(
      id: 'name',
      label: LocalizedText({'en': 'Name', 'fr': 'Nom'}),
      required: true,
    ),
  ];

  @override
  List<SecretField> get secrets => [
    SecretField(
      env: 'BB_MANUAL',
      label: const LocalizedText({'en': 'Key', 'fr': 'Clé'}),
      required: secretRequired,
    ),
  ];

  @override
  bool get providesHistory => true;

  @override
  Stream<SourceState> connect(SourceSettings settings, PluginContext context) {
    final controller = StreamController<SourceState>();
    connections.add((
      settings: settings,
      context: context,
      controller: controller,
    ));
    return controller.stream;
  }
}

SourceConfig _manual(String name) =>
    SourceConfig(type: 'manual', settings: {'name': name});

/// One tile per source; both of its zones follow the same source.
Config _config(List<SourceConfig> sources, {int pollSeconds = 30}) => Config(
  pollSeconds: pollSeconds,
  tiles: [
    Tile(
      id: 'master',
      label: 'BuildBeacon',
      kind: TileKind.master,
      chainIndex: 0,
      pos: const HexPos(0, 1),
    ),
    for (final (i, source) in sources.indexed)
      Tile(
        id: 't$i',
        label: 'Tile $i',
        kind: TileKind.project,
        chainIndex: i + 1,
        pos: HexPos(i, 0),
        zones: {
          ZoneName.ambient: ZoneAction(
            source: source,
            mode: DisplayMode.overall,
          ),
          ZoneName.dots: ZoneAction(source: source, mode: DisplayMode.history),
        },
      ),
  ],
);

final _noNetwork = MockClient((_) async => throw StateError('no network'));

void main() {
  late _ManualPlugin plugin;
  late SourceManager manager;

  setUp(() {
    plugin = _ManualPlugin();
    manager = SourceManager(
      plugins: PluginRegistry([plugin]),
      httpClient: _noNetwork,
      environment: {'BB_MANUAL': 'key', 'BB_GITHUB_TOKEN': 'token'},
    );
  });

  tearDown(() => manager.close());

  test(
    'une connexion par source distincte, partagée entre zones et tuiles',
    () async {
      final a = _manual('a');
      await manager.apply(_config([a, a, _manual('b')]));

      expect(plugin.connections.map((c) => c.settings.text('name')), [
        'a',
        'b',
      ]);
    },
  );

  test(
    'les états du plugin alimentent le cache et signalent un changement',
    () async {
      final a = _manual('a');
      await manager.apply(_config([a]));
      final changed = manager.changes.first;

      plugin.connections.single.controller.add(
        const SourceState(history: [Status.failure, Status.success]),
      );
      await changed;

      expect(manager.states[a.key]!.status, Status.failure);
    },
  );

  test('une erreur du flux garde le dernier état', () async {
    final a = _manual('a');
    await manager.apply(_config([a]));
    final controller = plugin.connections.single.controller;

    controller.add(const SourceState(history: [Status.success]));
    controller.addError('network down');
    await pumpEventQueue();

    expect(manager.states[a.key]!.history, [Status.success]);
    expect(manager.states[a.key]!.error?.resolve('fr'), 'network down');
  });

  test('une source qui ne sert plus est fermée et retirée du cache', () async {
    final a = _manual('a');
    final b = _manual('b');
    await manager.apply(_config([a, b]));
    plugin.connections[1].controller.add(const SourceState());
    await pumpEventQueue();

    await manager.apply(_config([a]));

    expect(plugin.connections[0].controller.hasListener, isTrue);
    expect(plugin.connections[1].controller.hasListener, isFalse);
    expect(manager.states.containsKey(b.key), isFalse);
  });

  test(
    'plugin absent ou réglages invalides : erreur traduite, sans connexion',
    () async {
      final gitlab = SourceConfig(
        type: 'gitlab',
        settings: {'repo': 'acme/app'},
      );
      final empty = SourceConfig(type: 'manual');
      await manager.apply(_config([gitlab, empty]));

      expect(plugin.connections, isEmpty);
      expect(
        manager.states[gitlab.key]!.error?.resolve('fr'),
        'aucun plugin « gitlab »',
      );
      expect(
        manager.states[gitlab.key]!.error?.resolve('en'),
        'no "gitlab" plugin',
      );
      expect(
        manager.states[empty.key]!.error?.resolve('fr'),
        '« Nom » est obligatoire',
      );
    },
  );

  test('secret obligatoire absent : erreur, sans connexion', () async {
    final strict = _ManualPlugin(secretRequired: true);
    final m = SourceManager(
      plugins: PluginRegistry([strict]),
      httpClient: _noNetwork,
    );
    final a = _manual('a');
    await m.apply(_config([a]));

    expect(strict.connections, isEmpty);
    expect(
      m.states[a.key]!.error?.resolve('fr'),
      contains('BB_MANUAL absente'),
    );
    await m.close();
  });

  test('un plugin ne reçoit que les secrets qu\'il déclare', () async {
    await manager.apply(_config([_manual('a')]));
    final context = plugin.connections.single.context;

    expect(context.secret('BB_MANUAL'), 'key');
    expect(context.secret('BB_GITHUB_TOKEN'), isNull);
    expect(context.pollInterval, const Duration(seconds: 30));
  });

  test(
    'nouvel intervalle : sources rouvertes, derniers états gardés',
    () async {
      final a = _manual('a');
      await manager.apply(_config([a]));
      plugin.connections.single.controller.add(
        const SourceState(history: [Status.success]),
      );
      await pumpEventQueue();

      await manager.apply(_config([a], pollSeconds: 60));

      expect(plugin.connections, hasLength(2));
      expect(plugin.connections[0].controller.hasListener, isFalse);
      expect(
        plugin.connections[1].context.pollInterval,
        const Duration(seconds: 60),
      );
      expect(manager.states[a.key]!.history, [Status.success]);
    },
  );

  group('plugins intégrés', () {
    test('GitHub fait partie du Hub', () {
      expect(builtinPlugins()['github'], isA<GithubPlugin>());
    });

    test('de bout en bout : config → plugin GitHub → cache', () async {
      final requests = <http.Request>[];
      final github = MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode({
            'workflow_runs': [
              {'status': 'completed', 'conclusion': 'success'},
              {'status': 'completed', 'conclusion': 'failure'},
            ],
          }),
          200,
        );
      });
      final hub = SourceManager(
        plugins: builtinPlugins(),
        httpClient: github,
        environment: {'BB_GITHUB_TOKEN': 'token'},
      );
      final app = SourceConfig(
        type: 'github',
        settings: {'repo': 'acme/app', 'workflow': 'ci.yml'},
      );

      final changed = hub.changes.first;
      await hub.apply(_config([app, app]));
      await changed;

      expect(hub.states[app.key]!.history, [Status.success, Status.failure]);
      expect(requests, hasLength(1));
      expect(requests.single.headers['Authorization'], 'Bearer token');
      await hub.close();
    });
  });
}
