// BuildBeacon Hub — Tests: the simulator follows config.json.
// Version 1.0 (2026-11-12)

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:buildbeacon_core/buildbeacon_core.dart';
import 'package:buildbeacon_hub/buildbeacon_hub.dart';
import 'package:test/test.dart';

String _config(List<String> labels) => jsonEncode(
  Config(
    tiles: [
      Tile(
        id: 'master',
        label: 'BuildBeacon',
        kind: TileKind.master,
        chainIndex: 0,
        pos: const HexPos(0, 1),
      ),
      for (final (i, label) in labels.indexed)
        Tile(
          id: 'tile-${i + 1}',
          label: label,
          kind: TileKind.project,
          chainIndex: i + 1,
          pos: HexPos(i, 0),
        ),
    ],
  ).toJson(),
);

void main() {
  late Directory dir;
  late String path;
  late List<Config?> seen;
  late List<String> logs;
  StreamSubscription<Config?>? subscription;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('bb-follow');
    path = '${dir.path}/data/config.json';
    seen = [];
    logs = [];
  });

  tearDown(() async {
    await subscription?.cancel();
    await dir.delete(recursive: true);
  });

  void follow() {
    subscription = followConfigFile(
      path,
      interval: const Duration(milliseconds: 20),
      log: (message) => logs.add(message.resolve('en')),
    ).listen(seen.add);
  }

  Future<void> later() =>
      Future<void>.delayed(const Duration(milliseconds: 120));

  void write(String text) {
    File(path)
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(text);
  }

  List<String?> labels() => [
    for (final config in seen) config?.tiles.map((t) => t.label).join(','),
  ];

  test('existing file: read right away, then each change', () async {
    write(_config(['App']));
    follow();
    await later();
    expect(labels(), ['BuildBeacon,App']);

    write(_config(['App', 'Site']));
    await later();
    expect(labels(), ['BuildBeacon,App', 'BuildBeacon,App,Site']);
    expect(logs.last, 'Layout from $path: 3 tiles.');
  });

  test('same content written again: nothing new', () async {
    write(_config(['App']));
    follow();
    await later();
    write(_config(['App']));
    await later();
    expect(seen, hasLength(1));
  });

  test(
    'missing file and folder: no layout, then the file once created',
    () async {
      follow();
      await later();
      expect(seen, [null]);
      expect(logs.single, contains('not found yet'));

      write(_config(['App']));
      await later();
      expect(labels(), [null, 'BuildBeacon,App']);
    },
  );

  test('invalid content: reported, previous layout kept', () async {
    write(_config(['App']));
    follow();
    await later();
    write('{ "tiles": [ ');
    await later();
    expect(seen, hasLength(1));
    expect(logs.last, endsWith('previous layout kept.'));

    write(_config(['Fixed']));
    await later();
    expect(labels(), ['BuildBeacon,App', 'BuildBeacon,Fixed']);
  });

  test('file removed: last layout kept', () async {
    write(_config(['App']));
    follow();
    await later();
    File(path).deleteSync();
    await later();
    expect(labels(), ['BuildBeacon,App']);
  });
}
