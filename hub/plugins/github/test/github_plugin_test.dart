// BuildBeacon Hub — Tests: GitHub plugin (conformance, settings, connection).
// Version 1.3 (2026-11-12) — comments in English.

import 'dart:convert';

import 'package:buildbeacon_plugin_github/buildbeacon_plugin_github.dart';
import 'package:buildbeacon_plugin_sdk/buildbeacon_plugin_sdk.dart';
import 'package:buildbeacon_plugin_sdk/testing.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

void main() {
  const plugin = GithubPlugin();

  test('respecte les règles du Hub', () {
    expect(conformanceIssues(plugin), isEmpty);
  });

  test('fournit un historique, pas de mesure ; jeton facultatif', () {
    expect(plugin.providesHistory, isTrue);
    expect(plugin.metrics, isEmpty);
    expect(plugin.secrets.single.env, 'BB_GITHUB_TOKEN');
    expect(plugin.secrets.single.required, isFalse);
  });

  test('libellés en français et en anglais', () {
    final repo = plugin.settings.first.label;
    expect(repo.resolve('fr'), 'Dépôt');
    expect(repo.resolve('en'), 'Repository');
    expect(plugin.description.resolve('fr'), startsWith('État des derniers'));
  });

  group('réglages', () {
    test('dépôt, workflow et branche corrects', () {
      expect(
        settingsIssues(plugin, {
          'repo': 'acme/app',
          'workflow': 'ci.yml',
          'branch': 'main',
        }),
        isEmpty,
      );
    });

    test('dépôt obligatoire', () {
      final issues = settingsIssues(plugin, {'workflow': 'ci.yml'});
      expect(issues.resolveAll('fr'), ['« Dépôt » est obligatoire']);
      expect(issues.resolveAll('en'), ['"Repository" is required']);
    });

    test('URL collée à la place de owner/repo', () {
      expect(
        settingsIssues(plugin, {
          'repo': 'https://github.com/acme/app',
        }).resolveAll('fr'),
        [contains('owner/repo attendu')],
      );
    });

    test('faute de frappe dans un réglage', () {
      expect(
        settingsIssues(plugin, {
          'repo': 'acme/app',
          'brnach': 'main',
        }).resolveAll('fr'),
        ['réglage inconnu « brnach » pour GitHub Actions'],
      );
    });
  });

  test('connexion : premier état lu tout de suite, avec le jeton', () async {
    final requests = <http.Request>[];
    final state = await firstState(
      plugin,
      {'repo': 'acme/app', 'branch': 'main'},
      context: fakeContext(
        secrets: {'BB_GITHUB_TOKEN': 'jeton'},
        respond: (request) {
          requests.add(request);
          return http.Response(
            jsonEncode({
              'workflow_runs': [
                {'status': 'completed', 'conclusion': 'success'},
                {'status': 'completed', 'conclusion': 'cancelled'},
              ],
            }),
            200,
          );
        },
      ),
    );

    expect(state.history, [Status.success, Status.cancelled]);
    expect(requests.single.url.queryParameters, {
      'per_page': '5',
      'branch': 'main',
    });
    expect(requests.single.headers['Authorization'], 'Bearer jeton');
  });
}
