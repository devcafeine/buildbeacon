// BuildBeacon Hub — API REST (shelf) : configuration, plugins, état en direct, actions.
// Version 1.0 (2026-11-11)

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:buildbeacon_core/buildbeacon_core.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_static/shelf_static.dart';

import '../hub_service.dart';
import 'snapshot.dart';

/// Version de l'API (incrémentée en cas de changement incompatible).
const apiVersion = 1;

/// Version du Hub annoncée par `/api/health`.
const hubVersion = '0.1.0';

/// Gestionnaire HTTP du Hub : l'API sous `/api`, l'interface web (fichiers de
/// [webDir], s'il existe) partout ailleurs.
///
/// Les requêtes qui modifient quelque chose (`POST`, `PUT`) doivent être en
/// JSON (`Content-Type: application/json`) : un site tiers ne peut donc pas
/// les déclencher depuis le navigateur d'un utilisateur, car il lui faudrait
/// une autorisation CORS que le Hub ne donne pas. Avec [apiToken], elles
/// exigent en plus `Authorization: Bearer <apiToken>`.
///
/// Les messages destinés à l'utilisateur sont renvoyés dans chaque langue de
/// l'interface : `{"en": "…", "fr": "…"}`.
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
      ? createStaticHandler(webDir, defaultDocument: 'index.html')
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

/// Flux Server-Sent Events : un événement `state` (même contenu que
/// `/api/state`) tout de suite, puis à chaque changement, au plus 4 par
/// seconde. Un commentaire toutes les 15 s garde la connexion ouverte.
Response _events(HubService service) {
  late final StreamController<List<int>> controller;
  StreamSubscription<void>? changes;
  Timer? pending;
  Timer? ping;

  void send() {
    pending = null;
    if (controller.isClosed) return;
    final data = jsonEncode(hubSnapshot(service.hub));
    controller.add(utf8.encode('event: state\ndata: $data\n\n'));
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

Response _home(Request request) {
  if (request.url.path.isNotEmpty) return _notFound(request);
  return _json({
    'name': 'BuildBeacon Hub',
    'api': '/api',
    'web_ui': 'not built yet',
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
// Garde des écritures et outils

/// Écritures en JSON seulement ; avec un jeton, `Authorization: Bearer …`.
Middleware _guardWrites(String? apiToken) =>
    (Handler inner) => (Request request) {
      const reads = {'GET', 'HEAD'};
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

/// Comparaison en temps constant, pour ne pas révéler le jeton caractère par
/// caractère.
bool _sameSecret(String a, String b) {
  final x = utf8.encode(a);
  final y = utf8.encode(b);
  var difference = x.length ^ y.length;
  for (var i = 0; i < x.length && i < y.length; i++) {
    difference |= x[i] ^ y[i];
  }
  return difference == 0;
}

/// Corps JSON de la requête (`null` s'il est vide), ou réponse 400.
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
