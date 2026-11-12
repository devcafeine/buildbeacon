// BuildBeacon Hub — Tests: Hub service (file reload, saving).
// Version 1.1 (2026-11-12) — comments in English.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:buildbeacon_core/buildbeacon_core.dart';
import 'package:buildbeacon_hub/buildbeacon_hub.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

final class _ManualPlugin extends SourcePlugin {
  final names = <String>[];

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
  Stream<SourceState> connect(SourceSettings settings, PluginContext context) {
    names.add(settings.text('name'));
    return StreamController<SourceState>().stream;
  }
}

final class _NullSink implements LedSink {
  @override
  void send(Uint8List rgb) {}
}

Map<String, Object?> _configJson(String source, {int poll = 30}) => {
  'poll_seconds': poll,
  'wled': {'host': '127.0.0.1'},
  'tiles': [
    {
      'id': 'master',
      'kind': 'master',
      'chain_index': 0,
      'pos': {'q': 0, 'r': 1},
    },
    {
      'id': 'app',
      'kind': 'project',
      'chain_index': 1,
      'pos': {'q': 0, 'r': 0},
      'zones': {
        'ambient': {
          'source': {'type': 'manual', 'name': source},
          'mode': 'overall',
        },
      },
    },
  ],
};

void main() {
  late Directory dir;
  late String path;
  late _ManualPlugin plugin;
  late Hub hub;
  late HubService service;
  late List<String> logs;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('bb-service');
    path = '${dir.path}/config.json';
    File(path).writeAsStringSync(jsonEncode(_configJson('a')));
    plugin = _ManualPlugin();
    logs = [];
    hub = Hub(
      plugins: PluginRegistry([plugin]),
      httpClient: MockClient(
        (_) async => throw http.ClientException('no WLED'),
      ),
      openOutput: (wled, log) async => (sink: _NullSink(), close: () async {}),
    );
    await hub.start(await readConfigFile(path));
    service = HubService(
      hub: hub,
      configPath: path,
      log: (message) => logs.add(message.resolve('fr')),
    );
  });

  tearDown(() async {
    await hub.stop();
    await dir.delete(recursive: true);
  });

  group('rechargement du fichier', () {
    test('fichier identique (ex. enregistré par l\'API) : ignoré', () async {
      await service.reloadFromDisk();
      expect(plugin.names, ['a']);
      expect(logs, isEmpty);
    });

    test('nouvelle version valide : appliquée', () async {
      File(path).writeAsStringSync(jsonEncode(_configJson('b')));
      await service.reloadFromDisk();
      expect(plugin.names, ['a', 'b']);
      expect(logs, ['Configuration rechargée']);
    });

    test('version invalide : refusée, la précédente gardée', () async {
      File(path).writeAsStringSync(jsonEncode(_configJson('b', poll: 1)));
      await service.reloadFromDisk();
      expect(plugin.names, ['a']);
      expect(logs.first, startsWith('Nouvelle configuration refusée'));
      expect(logs.last, contains('trop court'));
    });

    test('fichier illisible : la précédente gardée', () async {
      File(path).writeAsStringSync('{ pas du JSON');
      await service.reloadFromDisk();
      expect(plugin.names, ['a']);
      expect(logs.single, endsWith('la configuration précédente est gardée'));
    });
  });

  test('enregistrement impossible : rien n\'est appliqué', () async {
    // The config path is a non-empty directory: the rename fails.
    final blocked = Directory('${dir.path}/blocked')..createSync();
    File('${blocked.path}/x').writeAsStringSync('x');
    final stuck = HubService(hub: hub, configPath: blocked.path);

    final result = await stuck.update(_configJson('b'));
    expect(result, isA<ConfigNotSaved>());
    expect(plugin.names, ['a']);
  });

  test('écriture atomique : JSON lisible, aucun fichier temporaire', () async {
    final config = Config.fromJson(_configJson('c'));
    await writeConfigFile(path, config);

    final text = File(path).readAsStringSync();
    expect(text, startsWith('{\n  "version": 1,'));
    expect((await readConfigFile(path)).toJson(), config.toJson());
    expect(File('$path.tmp').existsSync(), isFalse);
  });
}
