// BuildBeacon Hub — Tests: REST API (configuration, plugins, state, actions, security).
// Version 1.3 (2026-11-12) — test names in English.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:buildbeacon_core/buildbeacon_core.dart';
import 'package:buildbeacon_hub/buildbeacon_hub.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

/// Plugin fed by hand by the test, with an optional secret.
final class _ManualPlugin extends SourcePlugin {
  final controllers = <String, StreamController<SourceState>>{};

  @override
  String get type => 'manual';

  @override
  LocalizedText get label =>
      const LocalizedText({'en': 'Manual', 'fr': 'Manuel'});

  @override
  LocalizedText get description => const LocalizedText.same('Test plugin.');

  @override
  List<SettingField> get settings => const [
    SettingField(id: 'name', label: LocalizedText.same('Name'), required: true),
  ];

  @override
  List<SecretField> get secrets => const [
    SecretField(env: 'BB_MANUAL_KEY', label: LocalizedText.same('Key')),
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

final class _NullSink implements LedSink {
  @override
  void send(Uint8List rgb) {}
}

Map<String, Object?> _configJson({
  String source = 'a',
  int brightness = 128,
  int poll = 30,
}) => {
  'version': 1,
  'wled': {'host': '127.0.0.1', 'brightness': brightness},
  'poll_seconds': poll,
  'tiles': [
    {
      'id': 'master',
      'label': 'BuildBeacon',
      'kind': 'master',
      'chain_index': 0,
      'pos': {'q': 0, 'r': 1},
    },
    {
      'id': 'app',
      'label': 'App',
      'kind': 'project',
      'chain_index': 1,
      'pos': {'q': 0, 'r': 0},
      'zones': {
        'ambient': {
          'source': {'type': 'manual', 'name': source},
          'mode': 'overall',
        },
        'dots': {
          'source': {'type': 'manual', 'name': source},
          'mode': 'history',
        },
      },
    },
  ],
};

void main() {
  late Directory dir;
  late String configPath;
  late _ManualPlugin plugin;
  late Hub hub;
  late HubService service;
  late List<String> logs;

  Future<Handler> start({
    String? apiToken,
    String? webDir,
    Map<String, String> environment = const {},
  }) async {
    dir = await Directory.systemTemp.createTemp('bb-api');
    configPath = '${dir.path}/config.json';
    File(configPath).writeAsStringSync(jsonEncode(_configJson()));
    plugin = _ManualPlugin();
    logs = [];
    hub = Hub(
      plugins: PluginRegistry([plugin]),
      httpClient: MockClient(
        (_) async => throw http.ClientException('no WLED'),
      ),
      environment: environment,
      openOutput: (wled, log) async => (sink: _NullSink(), close: () async {}),
      log: (message) => logs.add(message.resolve('fr')),
    );
    await hub.start(await readConfigFile(configPath));
    service = HubService(
      hub: hub,
      configPath: configPath,
      environment: environment,
      log: (message) => logs.add(message.resolve('fr')),
    );
    return hubHandler(service, apiToken: apiToken, webDir: webDir);
  }

  tearDown(() async {
    await hub.stop();
    await dir.delete(recursive: true);
  });

  Request request(
    String method,
    String path, {
    Object? body,
    String contentType = 'application/json',
    Map<String, String> headers = const {},
  }) => Request(
    method,
    Uri.parse('http://localhost$path'),
    body: body is String ? body : (body == null ? null : jsonEncode(body)),
    headers: {
      if (method != 'GET') HttpHeaders.contentTypeHeader: contentType,
      ...headers,
    },
  );

  Future<(int, Object?)> call(Handler handler, Request r) async {
    final response = await handler(r);
    final text = await response.readAsString();
    return (response.statusCode, text.isEmpty ? null : jsonDecode(text));
  }

  test('health: name, versions, languages', () async {
    final handler = await start();
    final (status, json) = await call(handler, request('GET', '/api/health'));
    expect(status, 200);
    expect(json, containsPair('api_version', 1));
    expect(json, containsPair('languages', ['en', 'fr']));
  });

  group('configuration', () {
    test('read', () async {
      final handler = await start();
      final (status, json) = await call(handler, request('GET', '/api/config'));
      expect(status, 200);
      expect(
        jsonEncode(json),
        jsonEncode(Config.fromJson(_configJson()).toJson()),
      );
    });

    test('replace: validated, hot-applied, saved', () async {
      final handler = await start();
      final (status, json) = await call(
        handler,
        request('PUT', '/api/config', body: _configJson(source: 'b')),
      );

      expect(status, 200);
      expect(json, containsPair('changed', true));
      expect(plugin.controllers['b']!.hasListener, isTrue);
      expect(plugin.controllers['a']!.hasListener, isFalse);
      final saved = await readConfigFile(configPath);
      expect(saved.toJson(), hub.config.toJson());
      expect(File('$configPath.tmp').existsSync(), isFalse);
      expect(
        logs,
        contains('Configuration modifiée par l\'API et enregistrée'),
      );
    });

    test(
      'identical to the current one: neither saved nor applied again',
      () async {
        final handler = await start();
        final (status, json) = await call(
          handler,
          request('PUT', '/api/config', body: _configJson()),
        );
        expect(status, 200);
        expect(json, containsPair('changed', false));
        expect(logs, isNot(contains(contains('par l\'API'))));
      },
    );

    test(
      'inconsistent: 422, issues in each language, nothing changes',
      () async {
        final handler = await start();
        final before = File(configPath).readAsStringSync();
        final (status, json) = await call(
          handler,
          request('PUT', '/api/config', body: _configJson(poll: 2)),
        );

        expect(status, 422);
        final issues =
            (json! as Map<String, Object?>)['issues']! as List<Object?>;
        expect(issues.single, {
          'en': 'Polling interval too short (2 s, minimum 10 s)',
          'fr': 'Intervalle de scrutation trop court (2 s, minimum 10 s)',
        });
        expect(File(configPath).readAsStringSync(), before);
        expect(hub.config.pollSeconds, 30);
      },
    );

    test('unreadable: 400, message in each language', () async {
      final handler = await start();
      final (status, json) = await call(
        handler,
        request('PUT', '/api/config', body: '{"tiles": [}'),
      );
      expect(status, 400);
      expect(
        ((json! as Map<String, Object?>)['error']!
            as Map<String, Object?>)['fr'],
        startsWith('JSON invalide'),
      );

      final (status2, _) = await call(
        handler,
        request('PUT', '/api/config', body: [1, 2]),
      );
      expect(status2, 400);
    });

    test('validate without applying', () async {
      final handler = await start();
      final (_, valid) = await call(
        handler,
        request('POST', '/api/config/validate', body: _configJson(source: 'z')),
      );
      expect(valid, {'valid': true, 'issues': <Object?>[]});
      expect(plugin.controllers.containsKey('z'), isFalse);

      final (_, invalid) = await call(
        handler,
        request('POST', '/api/config/validate', body: _configJson(poll: 1)),
      );
      expect(invalid, containsPair('valid', false));
    });
  });

  group('write security', () {
    test(
      'JSON required: 415 otherwise (protects against third-party sites)',
      () async {
        final handler = await start();
        final (status, _) = await call(
          handler,
          request(
            'PUT',
            '/api/config',
            body: jsonEncode(_configJson(source: 'b')),
            contentType: 'text/plain',
          ),
        );
        expect(status, 415);
        expect(plugin.controllers.containsKey('b'), isFalse);
      },
    );

    test(
      'with BB_API_TOKEN: 401 without the token, accepted with it',
      () async {
        final handler = await start(apiToken: 's3cret');
        final body = _configJson(source: 'b');

        final (refused, _) = await call(
          handler,
          request('PUT', '/api/config', body: body),
        );
        final (wrong, _) = await call(
          handler,
          request(
            'PUT',
            '/api/config',
            body: body,
            headers: {'authorization': 'Bearer nope'},
          ),
        );
        final (accepted, _) = await call(
          handler,
          request(
            'PUT',
            '/api/config',
            body: body,
            headers: {'authorization': 'Bearer s3cret'},
          ),
        );
        final (read, _) = await call(handler, request('GET', '/api/config'));

        expect([refused, wrong, accepted, read], [401, 401, 200, 200]);
      },
    );

    test('with BB_API_TOKEN: validating without the token still works '
        '(no effect), but JSON only', () async {
      final handler = await start(apiToken: 's3cret');
      final (status, json) = await call(
        handler,
        request('POST', '/api/config/validate', body: _configJson(poll: 1)),
      );
      expect(status, 200);
      expect(json, containsPair('valid', false));
      final (notJson, _) = await call(
        handler,
        request('POST', '/api/config/validate', contentType: 'text/plain'),
      );
      expect(notJson, 415);
      final (identify, _) = await call(
        handler,
        request('POST', '/api/tiles/app/identify'),
      );
      expect(identify, 401);
    });
  });

  test(
    'plugins: description, whether a secret is set, never its value',
    () async {
      final handler = await start(environment: {'BB_MANUAL_KEY': 'top-secret'});
      final response = await handler(request('GET', '/api/plugins'));
      final text = await response.readAsString();

      expect(text, isNot(contains('top-secret')));
      final plugins =
          (jsonDecode(text) as Map<String, Object?>)['plugins']!
              as List<Object?>;
      final manual = plugins.single! as Map<String, Object?>;
      expect(manual['label'], {'en': 'Manual', 'fr': 'Manuel'});
      expect(manual['secrets'], [
        {
          'env': 'BB_MANUAL_KEY',
          'label': {'en': 'Key', 'fr': 'Key'},
          'required': false,
          'configured': true,
        },
      ]);
    },
  );

  test('live state: zones, colors, sources, WLED', () async {
    final handler = await start();
    plugin.controllers['a']!.add(
      const SourceState(history: [Status.failure, Status.success]),
    );
    await pumpEventQueue();

    final (status, json) = await call(handler, request('GET', '/api/state'));
    expect(status, 200);
    final state = json! as Map<String, Object?>;
    expect(state['led_count'], 12);
    expect(state['pulsing'], ['running', 'queued']);

    final app = (state['tiles']! as List<Object?>)[1]! as Map<String, Object?>;
    final zones = app['zones']! as Map<String, Object?>;
    final ambient = zones['ambient']! as Map<String, Object?>;
    expect(ambient['mode'], 'overall');
    expect(
      ambient['leds'],
      everyElement({'status': 'failure', 'intensity': 1.0, 'color': '#FF0000'}),
    );
    final dots =
        (zones['dots']! as Map<String, Object?>)['leds']! as List<Object?>;
    expect(
      [for (final led in dots) (led! as Map<String, Object?>)['status']],
      ['failure', 'success', 'unknown', 'unknown', 'unknown'],
    );

    final source =
        (state['sources']! as Map<String, Object?>).values.single!
            as Map<String, Object?>;
    expect(source['label'], 'manual · a');
    expect(source['history'], ['failure', 'success']);

    final wled = state['wled']! as Map<String, Object?>;
    expect(wled['host'], '127.0.0.1');
    expect(wled['info'], isNull);
    expect(wled['error'], contains('no WLED'));
  });

  test('frame sent to the LEDs', () async {
    final handler = await start();
    final (status, json) = await call(handler, request('GET', '/api/frame'));
    expect(status, 200);
    expect(json, containsPair('led_count', 12));
    expect((json! as Map<String, Object?>)['leds'], hasLength(12 * 6));
  });

  group('identify a tile', () {
    test('the tile blinks', () async {
      final handler = await start();
      final (status, json) = await call(
        handler,
        request('POST', '/api/tiles/app/identify', body: {'seconds': 2}),
      );
      expect(status, 202);
      expect(json, {'tile': 'app', 'seconds': 2});
      expect(hub.identifying, {'app'});
    });

    test('unknown tile: 404; out-of-range duration: 400', () async {
      final handler = await start();
      final (unknown, _) = await call(
        handler,
        request('POST', '/api/tiles/nope/identify'),
      );
      final (tooLong, _) = await call(
        handler,
        request('POST', '/api/tiles/app/identify', body: {'seconds': 600}),
      );
      expect([unknown, tooLong], [404, 400]);
    });
  });

  test('recheck WLED', () async {
    final handler = await start();
    final (status, json) = await call(
      handler,
      request('POST', '/api/wled/check'),
    );
    expect(status, 200);
    expect(json, containsPair('error', contains('no WLED')));
  });

  group('live stream (SSE)', () {
    /// Received events (name, decoded data), as they arrive.
    Future<StreamIterator<(String, Object?)>> open(Handler handler) async {
      final response = await handler(request('GET', '/api/events'));
      expect(response.headers['content-type'], startsWith('text/event-stream'));
      final events = response
          .read()
          .transform(utf8.decoder)
          .where((chunk) => chunk.startsWith('event: '))
          .map((chunk) {
            final [name, data] = chunk.trim().split('\n');
            return (
              name.substring('event: '.length),
              jsonDecode(data.substring('data: '.length)),
            );
          });
      return StreamIterator(events);
    }

    Future<(String, Object?)> next(StreamIterator<(String, Object?)> it) async {
      expect(await it.moveNext().timeout(const Duration(seconds: 5)), isTrue);
      return it.current;
    }

    test('the configuration then the state, right away', () async {
      final events = await open(await start());
      final (first, config) = await next(events);
      expect(first, 'config');
      expect(config, containsPair('poll_seconds', 30));
      final (second, state) = await next(events);
      expect(second, 'state');
      expect(state, containsPair('led_count', 12));
      await events.cancel();
    });

    test('config sent again only when it changes', () async {
      final handler = await start();
      final events = await open(handler);
      await next(events); // config
      await next(events); // state

      // A state change alone: no new config.
      await Future<void>.delayed(Duration.zero);
      plugin.controllers['a']!.add(const SourceState(status: Status.success));
      expect((await next(events)).$1, 'state');

      await call(
        handler,
        request('PUT', '/api/config', body: _configJson(brightness: 90)),
      );
      final (name, config) = await next(events);
      expect(name, 'config');
      expect(config, containsPair('wled', containsPair('brightness', 90)));
      expect((await next(events)).$1, 'state');
      await events.cancel();
    });
  });

  group('outside the API', () {
    test('unknown route: translated JSON 404', () async {
      final handler = await start();
      final (status, json) = await call(handler, request('GET', '/api/nope'));
      expect(status, 404);
      expect(json, {
        'error': {
          'en': 'Not found: /api/nope',
          'fr': 'Introuvable : /api/nope',
        },
      });
    });

    test('without a web interface: the root describes the API', () async {
      final handler = await start();
      final (status, json) = await call(handler, request('GET', '/'));
      expect(status, 200);
      expect(json, containsPair('api', '/api'));
    });

    test('with a web interface: its files are served', () async {
      final web = await Directory.systemTemp.createTemp('bb-web');
      addTearDown(() => web.delete(recursive: true));
      File('${web.path}/index.html').writeAsStringSync('<h1>BuildBeacon</h1>');

      final handler = await start(webDir: web.path);
      final response = await handler(request('GET', '/'));
      expect(response.statusCode, 200);
      expect(await response.readAsString(), '<h1>BuildBeacon</h1>');
      // Revalidated every time: never a stale UI after an update.
      expect(response.headers['cache-control'], 'no-cache');

      final modified = response.headers['last-modified']!;
      final again = await handler(
        request('GET', '/', headers: {'if-modified-since': modified}),
      );
      expect(again.statusCode, 304);
    });
  });
}
