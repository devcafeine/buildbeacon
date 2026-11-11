// BuildBeacon Hub — Tests : lecture des runs GitHub (URL, ETag, quota, erreurs).
// Version 1.2 (2026-11-11) — messages d'erreur traduits, états en anglais.

import 'dart:convert';

import 'package:buildbeacon_plugin_github/buildbeacon_plugin_github.dart';
import 'package:buildbeacon_plugin_sdk/buildbeacon_plugin_sdk.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

String _runs(List<(String, String?)> runs) => jsonEncode({
  'total_count': runs.length,
  'workflow_runs': [
    for (final (i, (status, conclusion)) in runs.indexed)
      {'id': 1000 - i, 'status': status, 'conclusion': conclusion},
  ],
});

/// Faux GitHub : enregistre les requêtes et répond dans l'ordre de [responses]
/// (la dernière réponse est répétée).
final class _FakeGithub {
  _FakeGithub(this.responses);

  final List<http.Response> responses;
  final requests = <http.Request>[];

  late final client = MockClient((request) async {
    requests.add(request);
    return responses[(requests.length - 1).clamp(0, responses.length - 1)];
  });
}

/// Erreur de source dont le message français vérifie [fr] (texte ou matcher).
Matcher _sourceError(Object fr) => throwsA(
  isA<SourceException>().having((e) => e.message.resolve('fr'), 'fr', fr),
);

void main() {
  var now = DateTime(2026, 11, 11, 18);
  setUp(() => now = DateTime(2026, 11, 11, 18));

  GithubRunsReader reader(
    http.Client client, {
    String? workflow,
    String? branch,
    String? token,
  }) => GithubRunsReader(
    repo: 'acme/app',
    workflow: workflow,
    branch: branch,
    client: client,
    token: token,
    clock: () => now,
  );

  final noNetwork = MockClient((_) async => throw StateError('no network'));

  group('URL', () {
    test('tous les workflows, toutes les branches', () {
      expect(
        reader(noNetwork).uri.toString(),
        'https://api.github.com/repos/acme/app/actions/runs?per_page=5',
      );
    });

    test('un workflow et une branche', () {
      expect(
        reader(noNetwork, workflow: 'ci.yml', branch: 'main').uri.toString(),
        'https://api.github.com/repos/acme/app/actions/workflows/ci.yml/runs'
        '?per_page=5&branch=main',
      );
    });
  });

  group('lecture', () {
    test('runs du plus récent au plus ancien', () async {
      final github = _FakeGithub([
        http.Response(
          _runs([
            ('in_progress', null),
            ('completed', 'success'),
            ('completed', 'failure'),
          ]),
          200,
        ),
      ]);
      final state = await reader(github.client).read(SourceState.unknown);
      expect(state.history, [Status.running, Status.success, Status.failure]);
      expect(state.status, Status.running);
      expect(state.updatedAt, now);
      expect(state.error, isNull);
    });

    test('5 runs au plus', () async {
      final github = _FakeGithub([
        http.Response(_runs(List.filled(8, ('completed', 'success'))), 200),
      ]);
      final state = await reader(github.client).read(SourceState.unknown);
      expect(state.history, hasLength(5));
    });

    test('en-têtes : API versionnée, User-Agent, jeton s\'il existe', () async {
      final github = _FakeGithub([http.Response(_runs([]), 200)]);
      await reader(github.client, token: 'jeton').read(SourceState.unknown);
      await reader(github.client).read(SourceState.unknown);

      final [withToken, withoutToken] = github.requests;
      expect(withToken.headers, containsPair('Authorization', 'Bearer jeton'));
      expect(
        withToken.headers,
        containsPair('X-GitHub-Api-Version', '2022-11-28'),
      );
      expect(withToken.headers, containsPair('User-Agent', 'BuildBeacon-Hub'));
      expect(withoutToken.headers.containsKey('Authorization'), isFalse);
    });

    test('ETag : requête conditionnelle, 304 garde l\'historique', () async {
      final github = _FakeGithub([
        http.Response(
          _runs([('completed', 'failure')]),
          200,
          headers: {'etag': 'W/"abc"'},
        ),
        http.Response('', 304),
      ]);
      final r = reader(github.client);
      final first = await r.read(SourceState.unknown);
      now = now.add(const Duration(seconds: 30));
      final second = await r.read(
        first.withError(const LocalizedText.same('old error')),
      );

      expect(github.requests[0].headers.containsKey('If-None-Match'), isFalse);
      expect(
        github.requests[1].headers,
        containsPair('If-None-Match', 'W/"abc"'),
      );
      expect(second.history, [Status.failure]);
      expect(second.error, isNull);
      expect(second.updatedAt, now);
    });
  });

  group('erreurs (messages traduits)', () {
    Future<SourceState> readWith(http.Response response, {String? workflow}) =>
        reader(
          _FakeGithub([response]).client,
          workflow: workflow,
        ).read(SourceState.unknown);

    test('401 : jeton refusé', () {
      expect(
        readWith(http.Response('', 401)),
        _sourceError(contains('BB_GITHUB_TOKEN')),
      );
    });

    test('403 sans limite de quota : droits insuffisants', () {
      expect(
        readWith(http.Response('', 403)),
        _sourceError(contains('Actions: read')),
      );
    });

    test('404 : dépôt ou workflow introuvable', () {
      expect(
        readWith(http.Response('', 404), workflow: 'ci.yml'),
        _sourceError(startsWith('acme/app / ci.yml introuvable (404)')),
      );
    });

    test('autre code HTTP', () {
      expect(
        readWith(http.Response('', 502)),
        _sourceError('GitHub a répondu 502 pour acme/app'),
      );
    });

    test('réponse sans workflow_runs', () {
      expect(
        readWith(http.Response('{"message": "?"}', 200)),
        _sourceError(contains('inattendue')),
      );
    });
  });

  group('quota', () {
    test('quota épuisé : aucune requête jusqu\'à la remise à zéro', () async {
      final reset = now.add(const Duration(minutes: 15));
      final github = _FakeGithub([
        http.Response(
          '',
          403,
          headers: {
            'x-ratelimit-remaining': '0',
            'x-ratelimit-reset': '${reset.millisecondsSinceEpoch ~/ 1000}',
          },
        ),
        http.Response(_runs([('completed', 'success')]), 200),
      ]);
      final r = reader(github.client);

      await expectLater(
        r.read(SourceState.unknown),
        throwsA(
          isA<SourceException>()
              .having(
                (e) => e.message.resolve('fr'),
                'fr',
                'quota GitHub épuisé, reprise à 18:15',
              )
              .having(
                (e) => e.message.resolve('en'),
                'en',
                'GitHub quota exhausted, resuming at 18:15',
              ),
        ),
      );
      now = now.add(const Duration(minutes: 10));
      await expectLater(
        r.read(SourceState.unknown),
        _sourceError(contains('18:15')),
      );
      expect(github.requests, hasLength(1));

      now = now.add(const Duration(minutes: 6));
      final state = await r.read(SourceState.unknown);
      expect(state.history, [Status.success]);
      expect(github.requests, hasLength(2));
    });

    test('limite secondaire (429 + retry-after)', () async {
      final github = _FakeGithub([
        http.Response('', 429, headers: {'retry-after': '60'}),
      ]);
      final r = reader(github.client);

      await expectLater(
        r.read(SourceState.unknown),
        _sourceError('quota GitHub épuisé, reprise à 18:01'),
      );
      await expectLater(
        r.read(SourceState.unknown),
        throwsA(isA<SourceException>()),
      );
      expect(github.requests, hasLength(1));
    });
  });
}
