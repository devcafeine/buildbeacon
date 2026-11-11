// BuildBeacon UI — Client de l'API REST du Hub.
// Version 1.1 (2026-11-11) — repli sur une lecture régulière si le flux SSE reste muet.

import 'dart:async';
import 'dart:convert';

import 'package:buildbeacon_core/buildbeacon_core.dart';
import 'package:http/http.dart' as http;

import 'hub_events.dart';
import 'json_text.dart';
import 'plugin_info.dart';

/// Échec d'un appel à l'API.
final class ApiException implements Exception {
  const ApiException(this.status, {this.message, this.issues = const []});

  /// Code HTTP ; 0 = Hub injoignable (réseau).
  final int status;

  /// Message traduit renvoyé par le Hub, s'il y en a un.
  final LocalizedText? message;

  /// Problèmes d'une configuration refusée (422).
  final List<LocalizedText> issues;

  bool get unreachable => status == 0;

  /// `BB_API_TOKEN` exigé (ou faux).
  bool get unauthorized => status == 401;

  @override
  String toString() =>
      'ApiException($status${message == null ? '' : ': $message'})';
}

/// Appels à l'API du Hub qui sert la page : `<base>api/…`.
///
/// [base] est l'adresse de la page (le Hub la sert lui-même) ; en
/// développement, `web_dev_config.yaml` relaie `/api/` vers le Hub.
final class HubApi {
  HubApi({
    required this.base,
    http.Client? client,
    HubEventSource openEvents = openHubEvents,
    this.eventsPatience = const Duration(seconds: 5),
    this.pollInterval = const Duration(seconds: 2),
  }) : _client = client ?? http.Client(),
       _openEvents = openEvents;

  final Uri base;
  final http.Client _client;
  final HubEventSource _openEvents;

  /// Délai sans aucun événement après lequel l'interface lit l'état
  /// elle-même, toutes les [pollInterval].
  final Duration eventsPatience;
  final Duration pollInterval;

  /// Jeton des écritures (`BB_API_TOKEN` du Hub), saisi par l'utilisateur ;
  /// gardé en mémoire seulement.
  String? token;

  Future<Config> config() async =>
      Config.fromJson(_object(await _get('config')));

  Future<List<PluginInfo>> plugins() async {
    final json = _object(await _get('plugins'));
    return [
      for (final plugin in json['plugins'] as List<Object?>? ?? const [])
        PluginInfo.fromJson(plugin! as Map<String, Object?>),
    ];
  }

  /// Valide, enregistre et applique [config] ; renvoie la configuration
  /// enregistrée par le Hub.
  Future<Config> saveConfig(Config config) async {
    final json = _object(await _send('PUT', 'config', config.toJson()));
    return Config.fromJson(_object(json['config']));
  }

  /// Problèmes de [config], sans rien appliquer.
  Future<List<LocalizedText>> validate(Config config) async {
    final json = _object(
      await _send('POST', 'config/validate', config.toJson()),
    );
    return localizedList(json['issues']);
  }

  /// Fait clignoter la tuile [tileId] au mur.
  Future<void> identify(String tileId, {int seconds = 5}) => _send(
    'POST',
    'tiles/${Uri.encodeComponent(tileId)}/identify',
    {'seconds': seconds},
  );

  /// Revérifie WLED (nombre de LED, luminosité).
  Future<void> checkWled() => _send('POST', 'wled/check', const {});

  /// Événements en direct : `config` et `state`.
  ///
  /// Par le flux SSE du Hub ; si rien n'arrive pendant [eventsPatience]
  /// (relais qui retient le flux : serveur de développement de Flutter,
  /// proxy inverse avec mise en tampon), lecture de `/api/config` et
  /// `/api/state` toutes les [pollInterval], jusqu'au premier événement du
  /// flux.
  Stream<HubEvent> events() {
    late final StreamController<HubEvent> out;
    StreamSubscription<HubEvent>? stream;
    Timer? watchdog;
    Timer? poller;
    var streamed = false;

    Future<void> poll() async {
      try {
        final config = await _get('config');
        final state = await _get('state');
        if (streamed || out.isClosed) return;
        out
          ..add(const HubLinkChanged(open: true))
          ..add(HubMessage('config', jsonEncode(config)))
          ..add(HubMessage('state', jsonEncode(state)));
      } on ApiException {
        if (!streamed && !out.isClosed) {
          out.add(const HubLinkChanged(open: false));
        }
      }
    }

    out = StreamController<HubEvent>(
      onListen: () {
        stream = _openEvents(url('events')).listen((event) {
          if (event is HubMessage) {
            streamed = true;
            watchdog?.cancel();
            poller?.cancel();
            poller = null;
          }
          // Pendant la lecture régulière, l'état du flux muet ne compte pas.
          if (event is HubLinkChanged && poller != null) return;
          out.add(event);
        });
        watchdog = Timer(eventsPatience, () {
          if (streamed) return;
          poller = Timer.periodic(pollInterval, (_) => unawaited(poll()));
          unawaited(poll());
        });
      },
      onCancel: () async {
        watchdog?.cancel();
        poller?.cancel();
        await stream?.cancel();
      },
    );
    return out.stream;
  }

  Uri url(String path) => base.resolve('api/$path');

  void close() => _client.close();

  Future<Object?> _get(String path) => _send('GET', path, null);

  Future<Object?> _send(String method, String path, Object? body) async {
    final request = http.Request(method, url(path))
      ..headers['accept'] = 'application/json';
    if (method != 'GET') {
      // Les écritures doivent être en JSON (protection du Hub contre les
      // requêtes venues d'autres sites).
      request.headers['content-type'] = 'application/json';
      request.body = jsonEncode(body ?? const <String, Object?>{});
      if (token case final token? when token.isNotEmpty) {
        request.headers['authorization'] = 'Bearer $token';
      }
    }
    final http.Response response;
    try {
      response = await http.Response.fromStream(await _client.send(request));
    } on Object {
      throw const ApiException(0);
    }
    Object? json;
    try {
      json = response.body.isEmpty ? null : jsonDecode(response.body);
    } on FormatException {
      json = null;
    }
    if (response.statusCode >= 200 && response.statusCode < 300) return json;
    throw ApiException(
      response.statusCode,
      message: json is Map<String, Object?> && json['error'] != null
          ? localizedFromJson(json['error'])
          : null,
      issues: json is Map<String, Object?>
          ? localizedList(json['issues'])
          : const [],
    );
  }

  static Map<String, Object?> _object(Object? json) =>
      json is Map<String, Object?> ? json : const {};
}
