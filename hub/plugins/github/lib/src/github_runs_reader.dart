// BuildBeacon Hub — GitHub plugin: reading the latest GitHub Actions runs.
// Version 1.3 (2026-11-12) — comments in English.

import 'dart:convert';

import 'package:buildbeacon_plugin_sdk/buildbeacon_plugin_sdk.dart';
import 'package:http/http.dart' as http;

import 'github_status.dart';

/// Reads the latest runs of a repository, optionally filtered by workflow
/// and branch, while sparing the API quota:
/// - conditional requests (ETag): a 304 response does not count;
/// - quota exhausted: no more requests until it resets.
final class GithubRunsReader {
  GithubRunsReader({
    required this.repo,
    this.workflow,
    this.branch,
    required http.Client client,
    String? token,
    DateTime Function()? clock,
  }) : _client = client,
       _token = token,
       _now = clock ?? DateTime.now;

  /// As many runs as there are dots on a tile.
  static const runCount = 5;

  /// `owner/repo`.
  final String repo;

  /// File name (`ci.yml`) or id; `null` = all workflows.
  final String? workflow;

  /// `null` = all branches.
  final String? branch;

  final http.Client _client;
  final String? _token;
  final DateTime Function() _now;

  String? _etag;
  DateTime? _blockedUntil;

  Uri get uri => Uri.https(
    'api.github.com',
    workflow == null
        ? '/repos/$repo/actions/runs'
        : '/repos/$repo/actions/workflows/$workflow/runs',
    {'per_page': '$runCount', 'branch': ?branch},
  );

  /// Reads the runs, from newest to oldest. If GitHub answers 304 (nothing
  /// new), the history of [previous] is kept.
  ///
  /// Throws a [SourceException] with a translated message on failure.
  Future<SourceState> read(SourceState previous) async {
    if (_blockedUntil case final until? when _now().isBefore(until)) {
      throw SourceException(_quotaMessage(until));
    }

    final response = await _client.get(
      uri,
      headers: {
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
        'User-Agent': 'BuildBeacon-Hub',
        if (_token case final token?) 'Authorization': 'Bearer $token',
        'If-None-Match': ?_etag,
      },
    );

    final target = workflow == null ? repo : '$repo / $workflow';
    switch (response.statusCode) {
      case 200:
        _etag = response.headers['etag'];
        return SourceState(
          history: _parseRuns(response.body),
          updatedAt: _now(),
        );
      case 304:
        return SourceState(history: previous.history, updatedAt: _now());
      case 401:
        throw const SourceException(
          LocalizedText({
            'en': 'GitHub token refused (401): check BB_GITHUB_TOKEN',
            'fr': 'jeton GitHub refusé (401) : vérifier BB_GITHUB_TOKEN',
          }),
        );
      case 403 || 429 when _isRateLimited(response):
        final until = _resetTime(response);
        _blockedUntil = until;
        throw SourceException(_quotaMessage(until));
      case 403:
        throw SourceException(
          LocalizedText.build(
            (l) => tr(
              l,
              en:
                  'access denied (403) to $repo: does the token have '
                  '"Actions: read" on this repository?',
              fr:
                  'accès refusé (403) à $repo : le jeton a-t-il '
                  '« Actions: read » sur ce dépôt ?',
            ),
          ),
        );
      case 404:
        throw SourceException(
          LocalizedText.build(
            (l) => tr(
              l,
              en:
                  '$target not found (404), or private repository without '
                  'a token',
              fr: '$target introuvable (404), ou dépôt privé sans jeton',
            ),
          ),
        );
      default:
        final code = response.statusCode;
        throw SourceException(
          LocalizedText.build(
            (l) => tr(
              l,
              en: 'GitHub answered $code for $repo',
              fr: 'GitHub a répondu $code pour $repo',
            ),
          ),
        );
    }
  }

  static List<Status> _parseRuns(String body) {
    if (jsonDecode(body) case {'workflow_runs': final List<Object?> runs}) {
      return [
        for (final run in runs.take(runCount))
          if (run is Map<String, Object?>)
            statusFromGithub(
              status: switch (run['status']) {
                final String s => s,
                _ => null,
              },
              conclusion: switch (run['conclusion']) {
                final String c => c,
                _ => null,
              },
            ),
      ];
    }
    throw const SourceException(
      LocalizedText({
        'en': 'unexpected GitHub response (no workflow_runs field)',
        'fr': 'réponse GitHub inattendue (champ workflow_runs absent)',
      }),
    );
  }

  static bool _isRateLimited(http.Response response) =>
      response.headers['x-ratelimit-remaining'] == '0' ||
      response.headers.containsKey('retry-after');

  /// End of the block: `retry-after` (secondary rate limit), otherwise
  /// `x-ratelimit-reset`, otherwise one minute.
  DateTime _resetTime(http.Response response) {
    if (int.tryParse(response.headers['retry-after'] ?? '') case final s?) {
      return _now().add(Duration(seconds: s));
    }
    if (int.tryParse(response.headers['x-ratelimit-reset'] ?? '')
        case final epoch?) {
      return DateTime.fromMillisecondsSinceEpoch(epoch * 1000);
    }
    return _now().add(const Duration(minutes: 1));
  }

  static LocalizedText _quotaMessage(DateTime until) {
    final local = until.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    final time = '${two(local.hour)}:${two(local.minute)}';
    return LocalizedText.build(
      (l) => tr(
        l,
        en: 'GitHub quota exhausted, resuming at $time',
        fr: 'quota GitHub épuisé, reprise à $time',
      ),
    );
  }
}
