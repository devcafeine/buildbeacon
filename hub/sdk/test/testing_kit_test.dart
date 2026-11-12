// BuildBeacon Hub — SDK tests: plugin test harness (testing.dart).
// Version 1.3 (2026-11-12) — test names in English.

import 'package:buildbeacon_plugin_sdk/buildbeacon_plugin_sdk.dart';
import 'package:buildbeacon_plugin_sdk/testing.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

/// Minimal plugin: polls a URL, success if it answers.
final class _PingPlugin extends SourcePlugin {
  const _PingPlugin();

  @override
  String get type => 'ping';

  @override
  LocalizedText get label => const LocalizedText.same('Ping HTTP');

  @override
  LocalizedText get description => const LocalizedText({
    'en': 'Checks that a URL answers.',
    'fr': 'Vérifie qu\'une URL répond.',
  });

  @override
  List<SettingField> get settings => const [
    SettingField(id: 'url', label: LocalizedText.same('URL'), required: true),
  ];

  @override
  List<SecretField> get secrets => const [
    SecretField(
      env: 'BB_PING_TOKEN',
      label: LocalizedText({'en': 'Token', 'fr': 'Jeton'}),
    ),
  ];

  @override
  Stream<SourceState> connect(SourceSettings settings, PluginContext context) =>
      pollingStream(context.pollInterval, (_) async {
        final response = await context.httpClient.get(
          Uri.parse(settings.text('url')),
          headers: {
            if (context.secret('BB_PING_TOKEN') case final token?)
              'Authorization': 'Bearer $token',
          },
        );
        return SourceState(
          status: response.statusCode < 400 ? Status.success : Status.failure,
          updatedAt: context.now(),
        );
      });
}

void main() {
  const plugin = _PingPlugin();
  const settings = {'url': 'https://acme.fr/sante'};

  test('firstState: first state, with fake HTTP, secret and clock', () async {
    final requests = <http.Request>[];
    final state = await firstState(
      plugin,
      settings,
      context: fakeContext(
        secrets: {'BB_PING_TOKEN': 'jeton'},
        clock: () => DateTime(2026, 11, 11, 18),
        respond: (request) {
          requests.add(request);
          return http.Response('ok', 200);
        },
      ),
    );

    expect(state.status, Status.success);
    expect(state.updatedAt, DateTime(2026, 11, 11, 18));
    expect(requests.single.url.toString(), 'https://acme.fr/sante');
    expect(requests.single.headers['Authorization'], 'Bearer jeton');
  });

  test('firstStates: several reads with a short interval', () async {
    var calls = 0;
    final states = await firstStates(
      plugin,
      settings,
      2,
      context: fakeContext(
        pollInterval: const Duration(milliseconds: 1),
        respond: (_) => http.Response('', ++calls == 1 ? 200 : 503),
      ),
    );
    expect(states.map((s) => s.status), [Status.success, Status.failure]);
  });

  test('without a fake response, a request becomes a readable error', () async {
    final state = await firstState(plugin, settings);
    expect(
      state.error?.resolve('en'),
      contains('unexpected HTTP request: GET https://acme.fr/sante'),
    );
  });

  test('invalid settings: rejected before starting the plugin', () {
    expect(
      () => firstState(plugin, {}),
      throwsA(
        isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('"URL" is required'),
        ),
      ),
    );
  });
}
