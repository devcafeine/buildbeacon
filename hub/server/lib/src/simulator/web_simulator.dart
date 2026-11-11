// BuildBeacon Hub — Simulateur web : sert la page et diffuse les images reçues (SSE).
// Version 1.2 (2026-11-11) — adresses brutes (la page les présente dans sa langue).

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:buildbeacon_core/buildbeacon_core.dart';

import 'ddp_receiver.dart';
import 'web_page.dart';

/// Délai temps réel de WLED : sans image pendant ce temps, un vrai WLED
/// reprend son propre affichage.
const wledRealtimeTimeout = Duration(milliseconds: 2500);

/// Disposition envoyée à la page (`/layout`) : tuiles de [config] avec leur
/// place au mur, port DDP et adresses IPv4 à indiquer au Hub (la première
/// est celle de la boucle locale). Sans [config], la page aligne les tuiles
/// dans l'ordre de la chaîne.
Map<String, Object?> simulatorLayout({
  Config? config,
  required int ddpPort,
  List<String> addresses = const [],
}) => {
  'ddp_port': ddpPort,
  'timeout_ms': wledRealtimeTimeout.inMilliseconds,
  'addresses': addresses,
  'tiles': [
    for (final tile in config?.tiles ?? const <Tile>[])
      if (tile.kind == TileKind.master || tile.chainIndex >= 1)
        {
          'rank': tile.kind == TileKind.master ? 0 : tile.chainIndex,
          'kind': tile.kind.name,
          'label': tile.label.isEmpty ? tile.id : tile.label,
          'q': tile.pos.q,
          'r': tile.pos.r,
        },
  ],
};

/// Serveur HTTP du simulateur web :
/// - `/` : la page ;
/// - `/layout` : la disposition (JSON) ;
/// - `/events` : les images reçues, en Server-Sent Events (le navigateur ne
///   peut pas recevoir d'UDP lui-même).
final class WebSimulator {
  WebSimulator._(this._server, Stream<ReceivedFrame> frames, this._layout) {
    _server.listen(_handle);
    _subscription = frames.listen((frame) {
      _last = frame;
      _lastAt = DateTime.now();
      final event = _frameEvent(frame, Duration.zero);
      for (final client in _clients.toList()) {
        _write(client, event);
      }
    });
  }

  /// Démarre le serveur sur [port] (0 = port libre au hasard). Par défaut,
  /// seulement sur cette machine ; [address] = toutes les interfaces pour
  /// regarder le simulateur depuis un autre poste.
  static Future<WebSimulator> start({
    required Stream<ReceivedFrame> frames,
    required Map<String, Object?> layout,
    int port = 8090,
    InternetAddress? address,
  }) async => WebSimulator._(
    await HttpServer.bind(address ?? InternetAddress.loopbackIPv4, port),
    frames,
    layout,
  );

  final HttpServer _server;
  final Map<String, Object?> _layout;
  late final StreamSubscription<ReceivedFrame> _subscription;
  final _clients = <HttpResponse>{};
  ReceivedFrame? _last;
  DateTime? _lastAt;

  int get port => _server.port;

  /// Pages ouvertes en ce moment.
  int get viewers => _clients.length;

  Future<void> close() async {
    await _subscription.cancel();
    for (final client in _clients.toList()) {
      await client.close().catchError((Object _) {});
    }
    _clients.clear();
    await _server.close(force: true);
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    if (request.method != 'GET') {
      response.statusCode = HttpStatus.methodNotAllowed;
      await response.close();
      return;
    }
    switch (request.uri.path) {
      case '/':
        response.headers.contentType = ContentType.html;
        response.write(simulatorPage);
        await response.close();
      case '/layout':
        response.headers.contentType = ContentType.json;
        response.write(jsonEncode(_layout));
        await response.close();
      case '/events':
        response
          ..bufferOutput = false
          ..headers.contentType = ContentType(
            'text',
            'event-stream',
            charset: 'utf-8',
          )
          ..headers.set(HttpHeaders.cacheControlHeader, 'no-cache')
          ..write('retry: 1000\n\n');
        _clients.add(response);
        unawaited(response.done.whenComplete(() => _clients.remove(response)));
        // Une page qui arrive voit tout de suite la dernière image, avec son
        // âge : si le flux est arrêté, elle l'affiche comme tel.
        if ((_last, _lastAt) case (final frame?, final at?)) {
          _write(response, _frameEvent(frame, DateTime.now().difference(at)));
        }
      default:
        response.statusCode = HttpStatus.notFound;
        response.write('Not found: ${request.uri.path}');
        await response.close();
    }
  }

  void _write(HttpResponse client, String event) {
    try {
      client.write(event);
    } catch (_) {
      _clients.remove(client);
    }
  }

  static String _frameEvent(ReceivedFrame frame, Duration age) {
    final data = jsonEncode({
      'leds': _hex(frame.rgb),
      'from': frame.from.address,
      'age_ms': age.inMilliseconds,
    });
    return 'event: frame\ndata: $data\n\n';
  }

  static String _hex(Uint8List bytes) {
    final buffer = StringBuffer();
    for (final byte in bytes) {
      buffer.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }
}
