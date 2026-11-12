// BuildBeacon Hub — REST API (shelf): configuration, plugins, live state, actions.
// Version 1.4 (2026-11-12) — comments in English.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:buildbeacon_core/buildbeacon_core.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_static/shelf_static.dart';

import '../hub_service.dart';
import 'snapshot.dart';

/// API version (incremented on breaking changes).
const apiVersion = 1;

/// Hub version reported by `/api/health`.
const hubVersion = '0.1.0';

/// HTTP handler of the Hub: the API under `/api`, the web interface (files
/// of [webDir], if it exists) everywhere else.
///
/// Requests that change something (`POST`, `PUT`) must be JSON
/// (`Content-Type: application/json`): a third-party site therefore cannot
/// trigger them from a user's browser, since it would need a CORS
/// authorization the Hub does not grant. With [apiToken], they also require
/// `Authorization: Bearer <apiToken>`, except validating a configuration,
/// which changes nothing.
///
/// User-facing messages are returned in every interface language:
/// `{"en": "…", "fr": "…"}`.
Handler hubHandler(HubService service, {String? apiToken, String? webDir}) {
  final router = Router(notFoundHandler: _notFound)
    ..get('/api/health', (Request request) => _health(service))
    ..get(
      '/api/config',
      (Request request) => _json(service.hub.config.toJson()),
    )
    ..put('/api/config', (Request request) => _putConfig(service, request))
    ..post(
      '/api/config/validate',
      (Request request) => _validateConfig(service, request),
    )
    ..get('/api/plugins', (Request request) => _plugins(service))
    ..get('/api/state', (Request request) => _json(hubSnapshot(service.hub)))
    ..get('/api/frame', (Request request) => _frame(service))
    ..get('/api/events', (Request request) => _events(service))
    ..post(
      '/api/tiles/<id>/identify',
      (Request request, String id) => _identify(service, request, id),
    )
    ..post('/api/wled/check', (Request request) => _checkWled(service));

  final api = const Pipeline()
      .addMiddleware(_guardWrites(apiToken))
      .addHandler(router.call);
  final web = webDir != null && Directory(webDir).existsSync()
      ? _revalidated(createStaticHandler(webDir, defaultDocument: 'index.html'))
      : _home;
  return (Request request) {
    final path = request.url.path;
    return path == 'api' || path.startsWith('api/')
        ? api(request)
        : web(request);
  };
}

// ---------------------------------------------------------------------------
// Routes

Response _health(HubService service) => _json({
  'name': 'BuildBeacon Hub',
  'version': hubVersion,
  'api_version': apiVersion,
  'uptime_s': DateTime.now().difference(service.startedAt).inSeconds,
  'languages': supportedLanguages,
});

Future<Response> _putConfig(HubService service, Request request) async {
  final (json, error) = await _readJson(request);
  if (error != null) return error;
  return switch (await service.update(json)) {
    ConfigAccepted(:final config, :final changed) => _json({
      'config': config.toJson(),
      'changed': changed,
    }),
    ConfigUnreadable(error: final message) => _error(400, message),
    ConfigRejected(:final issues) => _json({
      'issues': [for (final issue in issues) issue.toJson()],
    }, status: 422),
    ConfigNotSaved(error: final message) => _error(500, message),
  };
}

Future<Response> _validateConfig(HubService service, Request request) async {
  final (json, error) = await _readJson(request);
  if (error != null) return error;
  return switch (service.validate(json)) {
    ConfigAccepted() => _json({'valid': true, 'issues': <Object?>[]}),
    ConfigRejected(:final issues) => _json({
      'valid': false,
      'issues': [for (final issue in issues) issue.toJson()],
    }),
    ConfigUnreadable(error: final message) => _error(400, message),
    ConfigNotSaved(error: final message) => _error(500, message),
  };
}

Response _plugins(HubService service) => _json({
  'plugins': [
    for (final plugin in service.plugins.all)
      pluginJson(plugin, service.environment),
  ],
});

Response _frame(HubService service) {
  final frame = service.hub.currentFrame();
  final hex = StringBuffer();
  for (final color in frame.pixels) {
    hex.write(color.toHex().substring(1).toLowerCase());
  }
  return _json({'led_count': frame.length, 'leds': hex.toString()});
}

/// Server-Sent Events stream: a `config` event (same content as
/// `GET /api/config`) then a `state` event (same content as `/api/state`)
/// right away; then, on every change, at most 4 per second, `config` if the
/// configuration changed (saved by the API or edited by hand) then `state`.
/// A comment every 15 s keeps the connection open.
Response _events(HubService service) {
  late final StreamController<List<int>> controller;
  StreamSubscription<void>? changes;
  Timer? pending;
  Timer? ping;
  String? lastConfig;

  void event(String name, String data) =>
      controller.add(utf8.encode('event: $name\ndata: $data\n\n'));

  void send() {
    pending = null;
    if (controller.isClosed) return;
    final config = jsonEncode(service.hub.config.toJson());
    if (config != lastConfig) {
      lastConfig = config;
      event('config', config);
    }
    event('state', jsonEncode(hubSnapshot(service.hub)));
  }

  controller = StreamController<List<int>>(
    onListen: () {
      send();
      changes = service.hub.changes.listen((_) {
        pending ??= Timer(const Duration(milliseconds: 250), send);
      });
      ping = Timer.periodic(const Duration(seconds: 15), (_) {
        if (!controller.isClosed) controller.add(utf8.encode(': ping\n\n'));
      });
    },
    onCancel: () async {
      pending?.cancel();
      ping?.cancel();
      await changes?.cancel();
    },
  );
  return Response.ok(
    controller.stream,
    headers: {
      HttpHeaders.contentTypeHeader: 'text/event-stream; charset=utf-8',
      HttpHeaders.cacheControlHeader: 'no-cache',
    },
    context: {'shelf.io.buffer_output': false},
  );
}

Future<Response> _identify(
  HubService service,
  Request request,
  String id,
) async {
  final (json, error) = await _readJson(request);
  if (error != null) return error;
  final seconds = switch (json) {
    {'seconds': final int s} => s,
    _ => 5,
  };
  if (seconds < 1 || seconds > 60) {
    return _error(
      400,
      const LocalizedText({
        'en': '"seconds" must be between 1 and 60',
        'fr': '« seconds » doit être compris entre 1 et 60',
      }),
    );
  }
  if (!service.hub.identify(id, duration: Duration(seconds: seconds))) {
    return _error(
      404,
      LocalizedText.build(
        (l) => tr(l, en: 'Unknown tile "$id"', fr: 'Tuile inconnue « $id »'),
      ),
    );
  }
  return _json({'tile': id, 'seconds': seconds}, status: 202);
}

Future<Response> _checkWled(HubService service) async {
  final status = await service.hub.checkWled();
  return _json(wledJson(service.hub.config, status));
}

/// The interface changes with the Hub: the browser revalidates each file
/// (304 if unchanged) instead of keeping an old version.
Handler _revalidated(Handler inner) => (Request request) async {
  final response = await inner(request);
  return response.change(headers: {HttpHeaders.cacheControlHeader: 'no-cache'});
};

Response _home(Request request) {
  if (request.url.path.isNotEmpty) return _notFound(request);
  return _json({
    'name': 'BuildBeacon Hub',
    'api': '/api',
    'web_ui': 'not built: mise run ui-build, then start the Hub with --web',
  });
}

Response _notFound(Request request) => _error(
  404,
  LocalizedText.build(
    (l) => tr(
      l,
      en: 'Not found: /${request.url.path}',
      fr: 'Introuvable : /${request.url.path}',
    ),
  ),
);

// ---------------------------------------------------------------------------
// Write guard and helpers

/// JSON-only writes; with a token, `Authorization: Bearer …` (except
/// `POST /api/config/validate`, which has no side effect: the interface
/// validates as the user types).
Middleware _guardWrites(String? apiToken) =>
    (Handler inner) => (Request request) {
      const reads = {'GET', 'HEAD'};
      const sideEffectFree = {'api/config/validate'};
      if (reads.contains(request.method)) return inner(request);
      final type = request.headers[HttpHeaders.contentTypeHeader] ?? '';
      if (!type.toLowerCase().startsWith('application/json')) {
        return _error(
          415,
          const LocalizedText({
            'en': 'Content-Type: application/json is required',
            'fr': 'Content-Type: application/json est obligatoire',
          }),
        );
      }
      if (apiToken != null &&
          !sideEffectFree.contains(request.url.path) &&
          !_sameSecret(
            request.headers[HttpHeaders.authorizationHeader] ?? '',
            'Bearer $apiToken',
          )) {
        return _error(
          401,
          const LocalizedText({
            'en': 'BB_API_TOKEN required: Authorization: Bearer <token>',
            'fr': 'BB_API_TOKEN exigé : Authorization: Bearer <jeton>',
          }),
        );
      }
      return inner(request);
    };

/// Constant-time comparison, so as not to reveal the token character by
/// character.
bool _sameSecret(String a, String b) {
  final x = utf8.encode(a);
  final y = utf8.encode(b);
  var difference = x.length ^ y.length;
  for (var i = 0; i < x.length && i < y.length; i++) {
    difference |= x[i] ^ y[i];
  }
  return difference == 0;
}

/// JSON body of the request (`null` if empty), or a 400 response.
Future<(Object?, Response?)> _readJson(Request request) async {
  final text = await request.readAsString();
  if (text.trim().isEmpty) return (null, null);
  try {
    return (jsonDecode(text), null);
  } on FormatException catch (e) {
    return (
      null,
      _error(
        400,
        LocalizedText.build(
          (l) => tr(
            l,
            en: 'Invalid JSON: ${e.message}',
            fr: 'JSON invalide : ${e.message}',
          ),
        ),
      ),
    );
  }
}

Response _json(Object? body, {int status = 200}) => Response(
  status,
  body: jsonEncode(body),
  headers: {HttpHeaders.contentTypeHeader: 'application/json; charset=utf-8'},
);

Response _error(int status, LocalizedText message) =>
    _json({'error': message.toJson()}, status: status);
