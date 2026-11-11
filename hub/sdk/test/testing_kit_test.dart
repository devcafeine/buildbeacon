// BuildBeacon Hub — Tests SDK : banc d'essai des plugins (testing.dart).
// Version 1.1 (2026-11-11) — textes traduits, messages pour développeurs en anglais.

import 'package:buildbeacon_plugin_sdk/buildbeacon_plugin_sdk.dart';
import 'package:buildbeacon_plugin_sdk/testing.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

/// Plugin minimal : interroge une URL, succès si elle répond.
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

  test(
    'firstState : premier état, avec HTTP simulé, secret et horloge',
    () async {
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
    },
  );

  test('firstStates : plusieurs lectures avec un intervalle court', () async {
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

  test(
    'sans réponse simulée, une requête devient une erreur lisible',
    () async {
      final state = await firstState(plugin, settings);
      expect(
        state.error?.resolve('en'),
        contains('unexpected HTTP request: GET https://acme.fr/sante'),
      );
    },
  );

  test('réglages invalides : refusés avant de lancer le plugin', () {
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
