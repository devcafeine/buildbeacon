// BuildBeacon UI — Client for the Hub's REST API.
// Version 1.2 (2026-11-12) — comments in English.

import 'dart:async';
import 'dart:convert';

import 'package:buildbeacon_core/buildbeacon_core.dart';
import 'package:http/http.dart' as http;

import 'hub_events.dart';
import 'json_text.dart';
import 'plugin_info.dart';

/// Failure of an API call.
final class ApiException implements Exception {
  const ApiException(this.status, {this.message, this.issues = const []});

  /// HTTP status code; 0 = Hub unreachable (network).
  final int status;

  /// Translated message returned by the Hub, if any.
  final LocalizedText? message;

  /// Issues of a rejected configuration (422).
  final List<LocalizedText> issues;

  bool get unreachable => status == 0;

  /// `BB_API_TOKEN` required (or wrong).
  bool get unauthorized => status == 401;

  @override
  String toString() =>
      'ApiException($status${message == null ? '' : ': $message'})';
}

/// Calls to the API of the Hub that serves the page: `<base>api/…`.
///
/// [base] is the page address (the Hub serves it itself); in development,
/// `web_dev_config.yaml` proxies `/api/` to the Hub.
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

  /// Time without any event after which the interface reads the state
  /// itself, every [pollInterval].
  final Duration eventsPatience;
  final Duration pollInterval;

  /// Token for writes (the Hub's `BB_API_TOKEN`), entered by the user;
  /// kept in memory only.
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

  /// Validates, saves and applies [config]; returns the configuration
  /// saved by the Hub.
  Future<Config> saveConfig(Config config) async {
    final json = _object(await _send('PUT', 'config', config.toJson()));
    return Config.fromJson(_object(json['config']));
  }

  /// Issues of [config], without applying anything.
  Future<List<LocalizedText>> validate(Config config) async {
    final json = _object(
      await _send('POST', 'config/validate', config.toJson()),
    );
    return localizedList(json['issues']);
  }

  /// Makes tile [tileId] blink on the wall.
  Future<void> identify(String tileId, {int seconds = 5}) => _send(
    'POST',
    'tiles/${Uri.encodeComponent(tileId)}/identify',
    {'seconds': seconds},
  );

  /// Checks WLED again (LED count, brightness).
  Future<void> checkWled() => _send('POST', 'wled/check', const {});

  /// Live events: `config` and `state`.
  ///
  /// Through the Hub's SSE stream; if nothing arrives within [eventsPatience]
  /// (a proxy that holds back the stream: Flutter's development server, a
  /// buffering reverse proxy), reads `/api/config` and `/api/state` every
  /// [pollInterval], until the first event of the stream.
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
          // While polling, the state of the silent stream does not count.
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
      // Writes must be JSON (protects the Hub against requests coming from
      // other sites).
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
