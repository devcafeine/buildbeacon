// BuildBeacon Hub — Web simulator: serves the page and streams the received frames (SSE).
// Version 1.4 (2026-11-12) — layout updated live (`layout` event).

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:buildbeacon_core/buildbeacon_core.dart';

import 'ddp_receiver.dart';
import 'web_page.dart';

/// WLED's realtime timeout: without a frame for this long, a real WLED goes
/// back to its own display.
const wledRealtimeTimeout = Duration(milliseconds: 2500);

/// Layout sent to the page (`/layout`): tiles of [config] with their place
/// on the wall, DDP port and IPv4 addresses to give to the Hub (the first
/// one is the loopback). Without [config], the page lines the tiles up in
/// chain order.
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

/// HTTP server of the web simulator:
/// - `/`: the page;
/// - `/layout`: the layout (JSON);
/// - `/events`: Server-Sent Events: the layout (`layout`, on connection and
///   on every change, see [updateLayout]) and the received frames (`frame`;
///   the browser cannot receive UDP itself).
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

  /// Starts the server on [port] (0 = random free port). By default, on this
  /// machine only; [address] = all interfaces to watch the simulator from
  /// another computer.
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
  Map<String, Object?> _layout;
  late final StreamSubscription<ReceivedFrame> _subscription;
  final _clients = <HttpResponse>{};
  ReceivedFrame? _last;
  DateTime? _lastAt;

  int get port => _server.port;

  /// Pages currently open.
  int get viewers => _clients.length;

  /// Replaces the layout (configuration changed): served on `/layout` and
  /// sent to the open pages, which redraw the wall.
  void updateLayout(Map<String, Object?> layout) {
    if (jsonEncode(layout) == jsonEncode(_layout)) return;
    _layout = layout;
    final event = _layoutEvent();
    for (final client in _clients.toList()) {
      _write(client, event);
    }
  }

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
        // The layout first: it may have changed since the page read /layout.
        _write(response, _layoutEvent());
        // A newly connected page immediately gets the last frame, with its
        // age: if the stream has stopped, it shows it as such.
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

  String _layoutEvent() => 'event: layout\ndata: ${jsonEncode(_layout)}\n\n';

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
