// BuildBeacon Hub — Tests: GitHub plugin (conformance, settings, connection).
// Version 1.4 (2026-11-12) — test names in English.

import 'dart:convert';

import 'package:buildbeacon_plugin_github/buildbeacon_plugin_github.dart';
import 'package:buildbeacon_plugin_sdk/buildbeacon_plugin_sdk.dart';
import 'package:buildbeacon_plugin_sdk/testing.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

void main() {
  const plugin = GithubPlugin();

  test('follows the Hub rules', () {
    expect(conformanceIssues(plugin), isEmpty);
  });

  test('provides history, no metrics; optional token', () {
    expect(plugin.providesHistory, isTrue);
    expect(plugin.metrics, isEmpty);
    expect(plugin.secrets.single.env, 'BB_GITHUB_TOKEN');
    expect(plugin.secrets.single.required, isFalse);
  });

  test('labels in French and English', () {
    final repo = plugin.settings.first.label;
    expect(repo.resolve('fr'), 'Dépôt');
    expect(repo.resolve('en'), 'Repository');
    expect(plugin.description.resolve('fr'), startsWith('État des derniers'));
  });

  group('settings', () {
    test('valid repository, workflow and branch', () {
      expect(
        settingsIssues(plugin, {
          'repo': 'acme/app',
          'workflow': 'ci.yml',
          'branch': 'main',
        }),
        isEmpty,
      );
    });

    test('repository required', () {
      final issues = settingsIssues(plugin, {'workflow': 'ci.yml'});
      expect(issues.resolveAll('fr'), ['« Dépôt » est obligatoire']);
      expect(issues.resolveAll('en'), ['"Repository" is required']);
    });

    test('URL pasted instead of owner/repo', () {
      expect(
        settingsIssues(plugin, {
          'repo': 'https://github.com/acme/app',
        }).resolveAll('fr'),
        [contains('owner/repo attendu')],
      );
    });

    test('typo in a setting', () {
      expect(
        settingsIssues(plugin, {
          'repo': 'acme/app',
          'brnach': 'main',
        }).resolveAll('fr'),
        ['réglage inconnu « brnach » pour GitHub Actions'],
      );
    });
  });

  test('connection: first state read immediately, with the token', () async {
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
