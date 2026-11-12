// BuildBeacon Hub — Tests: web simulator (page, layout, SSE stream).
// Version 1.5 (2026-11-12) — layout pushed to the open pages.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:buildbeacon_core/buildbeacon_core.dart';
import 'package:buildbeacon_hub/buildbeacon_hub.dart';
import 'package:test/test.dart';

/// The user's layout: master at (0, 1), tiles at (0, 0) and (1, 1).
final _config = Config(
  tiles: [
    Tile(
      id: 'master',
      label: 'BuildBeacon',
      kind: TileKind.master,
      chainIndex: 0,
      pos: const HexPos(0, 1),
    ),
    Tile(
      id: 'app',
      label: 'App',
      kind: TileKind.project,
      chainIndex: 1,
      pos: const HexPos(0, 0),
    ),
    Tile(
      id: 'bambu',
      label: '',
      kind: TileKind.project,
      chainIndex: 2,
      pos: const HexPos(1, 1),
    ),
  ],
);

ReceivedFrame _frame(List<int> rgb) =>
    (rgb: Uint8List.fromList(rgb), from: InternetAddress.loopbackIPv4);

void main() {
  late StreamController<ReceivedFrame> frames;
  late WebSimulator web;
  late HttpClient client;

  setUp(() async {
    frames = StreamController<ReceivedFrame>.broadcast();
    web = await WebSimulator.start(
      frames: frames.stream,
      layout: simulatorLayout(
        config: _config,
        ddpPort: 4048,
        addresses: ['127.0.0.1', '192.168.1.20'],
      ),
      port: 0,
    );
    client = HttpClient();
  });

  tearDown(() async {
    client.close(force: true);
    await web.close();
    await frames.close();
  });

  Future<HttpClientResponse> get(String path) async => (await client.getUrl(
    Uri.parse('http://127.0.0.1:${web.port}$path'),
  )).close();

  /// Reads the SSE stream and returns the data of the first "frame" event.
  Future<Map<String, Object?>> nextFrame(Stream<String> lines) async {
    var isFrame = false;
    await for (final line in lines) {
      if (line == 'event: frame') {
        isFrame = true;
      } else if (isFrame && line.startsWith('data: ')) {
        return jsonDecode(line.substring(6)) as Map<String, Object?>;
      }
    }
    throw StateError('stream ended without a frame');
  }

  test('the page, bilingual', () async {
    final response = await get('/');
    expect(response.statusCode, 200);
    expect(response.headers.contentType?.mimeType, 'text/html');
    final body = await utf8.decodeStream(response);
    expect(body, contains('<title>BuildBeacon simulator</title>'));
    expect(body, contains('new EventSource("events")'));
    expect(
      body,
      allOf(contains('"WLED simulator"'), contains('"Simulateur WLED"')),
    );
  });

  test(
    'the layout: tiles from config.json at their place on the wall',
    () async {
      final response = await get('/layout');
      expect(response.headers.contentType?.mimeType, 'application/json');
      final layout =
          jsonDecode(await utf8.decodeStream(response)) as Map<String, Object?>;

      expect(layout['ddp_port'], 4048);
      expect(layout['timeout_ms'], 2500);
      expect(layout['addresses'], ['127.0.0.1', '192.168.1.20']);
      expect(layout['tiles'], [
        {'rank': 0, 'kind': 'master', 'label': 'BuildBeacon', 'q': 0, 'r': 1},
        {'rank': 1, 'kind': 'project', 'label': 'App', 'q': 0, 'r': 0},
        {'rank': 2, 'kind': 'project', 'label': 'bambu', 'q': 1, 'r': 1},
      ]);
    },
  );

  /// Reads the SSE stream and returns the data of the next [name] event.
  Future<Map<String, Object?>> nextEvent(
    Stream<String> lines,
    String name,
  ) async {
    var wanted = false;
    await for (final line in lines) {
      if (line.startsWith('event: ')) {
        wanted = line == 'event: $name';
      } else if (wanted && line.startsWith('data: ')) {
        return jsonDecode(line.substring(6)) as Map<String, Object?>;
      }
    }
    throw StateError('stream ended without a $name event');
  }

  test(
    'layout changed: sent to the open pages and served on /layout',
    () async {
      final response = await get('/events');
      final lines = response
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .asBroadcastStream();

      // On connection: the current layout.
      final first = await nextEvent(
        lines,
        'layout',
      ).timeout(const Duration(seconds: 5));
      expect(first['tiles'], hasLength(3));

      final moved = Config(
        tiles: [
          ..._config.tiles,
          Tile(
            id: 'site',
            label: 'Site',
            kind: TileKind.project,
            chainIndex: 3,
            pos: const HexPos(1, 0),
          ),
        ],
      );
      final layout = simulatorLayout(config: moved, ddpPort: 4048);
      web.updateLayout(layout);
      final second = await nextEvent(
        lines,
        'layout',
      ).timeout(const Duration(seconds: 5));
      expect(second['tiles'], hasLength(4));
      expect((second['tiles']! as List).last, {
        'rank': 3,
        'kind': 'project',
        'label': 'Site',
        'q': 1,
        'r': 0,
      });

      final served = await utf8.decodeStream(await get('/layout'));
      expect(jsonDecode(served), layout);
    },
  );

  test('without config.json: no tiles imposed', () {
    expect(simulatorLayout(ddpPort: 4048)['tiles'], isEmpty);
  });

  test('received frames are sent to the page (SSE)', () async {
    final response = await get('/events');
    expect(response.headers.contentType?.mimeType, 'text/event-stream');
    final lines = response
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .asBroadcastStream();

    await pumpEventQueue();
    expect(web.viewers, 1);
    frames.add(_frame([255, 80, 0, 0, 0, 0]));

    final data = await nextFrame(lines).timeout(const Duration(seconds: 5));
    expect(data, {'leds': 'ff5000000000', 'from': '127.0.0.1', 'age_ms': 0});
  });

  test('a newly opened page sees the last frame, with its age', () async {
    frames.add(_frame([0, 255, 0]));
    await Future<void>.delayed(const Duration(milliseconds: 150));

    final response = await get('/events');
    final lines = response
        .transform(utf8.decoder)
        .transform(const LineSplitter());
    final data = await nextFrame(lines).timeout(const Duration(seconds: 5));
    expect(data['leds'], '00ff00');
    expect(data['age_ms'], greaterThanOrEqualTo(100));
  });

  test('closed page: no longer served', () async {
    final response = await get('/events');
    final subscription = response.listen((_) {});
    await pumpEventQueue();
    expect(web.viewers, 1);

    await subscription.cancel();
    client.close(force: true);
    frames.add(_frame([1, 2, 3]));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(web.viewers, 0);
  });

  test('unknown path: 404; method other than GET: 405', () async {
    expect((await get('/unknown')).statusCode, 404);
    final post = await (await client.postUrl(
      Uri.parse('http://127.0.0.1:${web.port}/'),
    )).close();
    expect(post.statusCode, 405);
  });
}
