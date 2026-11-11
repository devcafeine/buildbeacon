// BuildBeacon Hub — Tests : simulateur web (page, disposition, flux SSE).
// Version 1.2 (2026-11-11) — page bilingue, adresses brutes, type de tuile en anglais.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:buildbeacon_core/buildbeacon_core.dart';
import 'package:buildbeacon_hub/buildbeacon_hub.dart';
import 'package:test/test.dart';

/// Disposition de l'utilisateur : master en (0, 1), tuiles en (0, 0) et (1, 1).
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

  /// Lit le flux SSE et renvoie les données du premier événement « frame ».
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

  test('la page, bilingue', () async {
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

  test('la disposition : tuiles de config.json à leur place au mur', () async {
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
  });

  test('sans config.json : pas de tuile imposée', () {
    expect(simulatorLayout(ddpPort: 4048)['tiles'], isEmpty);
  });

  test('les images reçues partent vers la page (SSE)', () async {
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

  test('une page qui arrive voit la dernière image, avec son âge', () async {
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

  test('page fermée : elle n\'est plus servie', () async {
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

  test('adresse inconnue : 404 ; autre méthode que GET : 405', () async {
    expect((await get('/unknown')).statusCode, 404);
    final post = await (await client.postUrl(
      Uri.parse('http://127.0.0.1:${web.port}/'),
    )).close();
    expect(post.statusCode, 405);
  });
}
