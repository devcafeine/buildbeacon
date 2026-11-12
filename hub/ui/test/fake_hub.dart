// BuildBeacon UI — Tests: in-memory fake Hub (REST API and event stream).
// Version 1.1 (2026-11-12) — comments in English.

import 'dart:async';
import 'dart:convert';

import 'package:buildbeacon_ui/src/api/hub_api.dart';
import 'package:buildbeacon_ui/src/api/hub_events.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Plugins: GitHub (history, optional secret) and a printer
/// (measurements, for the thresholds and gauge modes).
const pluginsJson = {
  'plugins': [
    {
      'type': 'github',
      'label': {'en': 'GitHub Actions', 'fr': 'GitHub Actions'},
      'description': {'en': 'Workflow runs.', 'fr': 'Runs de workflow.'},
      'settings': [
        {
          'id': 'repo',
          'label': {'en': 'Repository', 'fr': 'Dépôt'},
          'kind': 'text',
          'required': true,
          'placeholder': 'owner/repo',
          'pattern': r'[\w.-]+/[\w.-]+',
          'pattern_hint': {'en': 'owner/repo', 'fr': 'owner/repo'},
        },
        {
          'id': 'branch',
          'label': {'en': 'Branch', 'fr': 'Branche'},
          'kind': 'text',
          'required': false,
        },
      ],
      'secrets': [
        {
          'env': 'BB_GITHUB_TOKEN',
          'label': {'en': 'Token', 'fr': 'Jeton'},
          'required': false,
          'help': {
            'en': 'Public repositories only.',
            'fr': 'Dépôts publics seulement.',
          },
          'configured': false,
        },
      ],
      'provides_history': true,
      'metrics': <Object?>[],
      'dynamic_metrics': false,
    },
    {
      'type': 'printer',
      'label': {'en': '3D printer', 'fr': 'Imprimante 3D'},
      'description': {'en': 'Print job.', 'fr': 'Impression.'},
      'settings': [
        {
          'id': 'host',
          'label': {'en': 'Address', 'fr': 'Adresse'},
          'kind': 'text',
          'required': true,
        },
      ],
      'secrets': <Object?>[],
      'provides_history': false,
      'metrics': [
        {
          'id': 'progress',
          'label': {'en': 'Progress', 'fr': 'Progression'},
          'unit': '%',
          'min': 0,
          'max': 100,
        },
      ],
      'dynamic_metrics': false,
    },
  ],
};

Map<String, Object?> configJson({String label = 'App', int brightness = 128}) =>
    {
      'version': 1,
      'wled': {
        'host': '127.0.0.1',
        'port': 80,
        'ddp_port': 4048,
        'brightness': brightness,
      },
      'poll_seconds': 60,
      'tiles': [
        {
          'id': 'master',
          'label': 'BuildBeacon',
          'kind': 'master',
          'chain_index': 0,
          'pos': {'q': 0, 'r': 1},
          'zones': {'system': null},
        },
        {
          'id': 'app',
          'label': label,
          'kind': 'project',
          'chain_index': 1,
          'pos': {'q': 0, 'r': 0},
          'zones': {
            'ambient': {
              'source': {'type': 'github', 'repo': 'acme/app'},
              'mode': 'overall',
            },
            'dots': {
              'source': {'type': 'github', 'repo': 'acme/app'},
              'mode': 'history',
            },
          },
        },
        {
          'id': 'site',
          'label': 'Site',
          'kind': 'project',
          'chain_index': 2,
          'pos': {'q': 1, 'r': 1},
          'zones': {'ambient': null, 'dots': null},
        },
      ],
    };

const sourceKey = 'github:{"repo":"acme/app"}';

Map<String, Object?> stateJson({List<String> identifying = const []}) => {
  'led_count': 21,
  'tiles': [
    for (final id in ['master', 'app', 'site'])
      {'id': id, 'identifying': identifying.contains(id)},
  ],
  'sources': {
    sourceKey: {
      'type': 'github',
      'settings': {'repo': 'acme/app'},
      'status': 'failure',
      'history': ['failure', 'success', 'success'],
      'metrics': <String, Object?>{},
      'error': null,
      'updated_at': '2026-11-11T21:55:46Z',
    },
  },
  'wled': {
    'host': '127.0.0.1',
    'checked_at': '2026-11-11T21:55:40Z',
    'info': {'version': '0.15.0', 'name': 'WLED', 'led_count': 21},
    'error': null,
  },
};

/// Issues found by the fake Hub: an empty GitHub repository.
List<Object?> fakeIssues(Map<String, Object?> config) => [
  for (final tile in config['tiles']! as List<Object?>)
    for (final zone in ((tile! as Map)['zones'] as Map? ?? {}).values)
      if (zone is Map &&
          (zone['source'] as Map)['type'] == 'github' &&
          (zone['source'] as Map)['repo'] == null)
        {
          'en': 'Tile "${(tile as Map)['id']}": "Repository" is required',
          'fr': 'Tuile « ${tile['id']} » : « Dépôt » est obligatoire',
        },
];

/// Fake Hub: keeps the configuration, answers like the API, logs the
/// calls; [events] feeds the live stream.
final class FakeHub {
  FakeHub({this.apiToken});

  final String? apiToken;
  Map<String, Object?> config = configJson();
  final requests = <String>[];
  final events = StreamController<HubEvent>.broadcast();
  bool reachable = true;

  HubApi api({Duration eventsPatience = const Duration(seconds: 5)}) => HubApi(
    base: Uri.parse('http://hub.local:8080/'),
    client: MockClient(_handle),
    openEvents: (_) => events.stream,
    eventsPatience: eventsPatience,
    pollInterval: const Duration(milliseconds: 20),
  );

  void sendConfig(Map<String, Object?> json) =>
      events.add(HubMessage('config', jsonEncode(json)));

  void sendState(Map<String, Object?> json) =>
      events.add(HubMessage('state', jsonEncode(json)));

  Future<http.Response> _handle(http.Request request) async {
    if (!reachable) throw http.ClientException('refused');
    final path = request.url.path;
    requests.add('${request.method} $path');
    http.Response json(Object? body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

    if (request.method != 'GET' &&
        path != '/api/config/validate' &&
        apiToken != null) {
      if (request.headers['authorization'] != 'Bearer $apiToken') {
        return json({
          'error': {'en': 'Token required', 'fr': 'Jeton exigé'},
        }, 401);
      }
    }
    switch ((request.method, path)) {
      case ('GET', '/api/config'):
        return json(config);
      case ('GET', '/api/plugins'):
        return json(pluginsJson);
      case ('GET', '/api/state'):
        return json(stateJson());
      case ('PUT', '/api/config'):
        final body = jsonDecode(request.body) as Map<String, Object?>;
        final issues = fakeIssues(body);
        if (issues.isNotEmpty) return json({'issues': issues}, 422);
        config = body;
        return json({'config': body, 'changed': true});
      case ('POST', '/api/config/validate'):
        final issues = fakeIssues(
          jsonDecode(request.body) as Map<String, Object?>,
        );
        return json({'valid': issues.isEmpty, 'issues': issues});
      case ('POST', '/api/wled/check'):
        return json(stateJson()['wled']);
    }
    final identify = RegExp(r'^/api/tiles/([^/]+)/identify$').firstMatch(path);
    if (request.method == 'POST' && identify != null) {
      final id = Uri.decodeComponent(identify[1]!);
      final known = (config['tiles']! as List<Object?>).any(
        (t) => (t! as Map)['id'] == id,
      );
      return known
          ? json({'tile': id, 'seconds': 5}, 202)
          : json({
              'error': {'en': 'Unknown tile', 'fr': 'Tuile inconnue'},
            }, 404);
    }
    return json({
      'error': {'en': 'Not found', 'fr': 'Introuvable'},
    }, 404);
  }
}
