// BuildBeacon Hub — Tests: reading config.json and first start.
// Version 1.2 (2026-11-12) — test names in English.

import 'dart:convert';
import 'dart:io';

import 'package:buildbeacon_core/buildbeacon_core.dart';
import 'package:buildbeacon_hub/buildbeacon_hub.dart';
import 'package:test/test.dart';

void main() {
  late Directory dir;

  setUp(() async => dir = await Directory.systemTemp.createTemp('bb-config'));
  tearDown(() => dir.delete(recursive: true));

  group('first start', () {
    test(
      'missing file: created with the master tile only, folder included',
      () async {
        final path = '${dir.path}/data/config.json';
        final (:config, :created) = await readOrCreateConfigFile(path);

        expect(created, isTrue);
        expect(config.tiles.single.kind, TileKind.master);
        expect(config.validate(), isEmpty);
        // The written file reads back unchanged.
        expect((await readConfigFile(path)).toJson(), config.toJson());
        expect(File('$path.tmp').existsSync(), isFalse);
      },
    );

    test('existing file: read, not recreated', () async {
      final path = '${dir.path}/config.json';
      final mine = Config.initial().toJson()..['poll_seconds'] = 300;
      File(path).writeAsStringSync(jsonEncode(mine));

      final (:config, :created) = await readOrCreateConfigFile(path);
      expect(created, isFalse);
      expect(config.pollSeconds, 300);
    });

    test('unreadable file: error, never replaced', () async {
      final path = '${dir.path}/config.json';
      File(path).writeAsStringSync('{ pas du JSON');

      await expectLater(
        readOrCreateConfigFile(path),
        throwsA(isA<LocalizedFormatException>()),
      );
      expect(File(path).readAsStringSync(), '{ pas du JSON');
    });

    test('path taken by a folder: error, nothing created', () async {
      final path = '${dir.path}/config.json';
      Directory(path).createSync();
      await expectLater(
        readOrCreateConfigFile(path),
        throwsA(isA<LocalizedFormatException>()),
      );
    });
  });

  test('read: missing file reported with its path', () async {
    final path = '${dir.path}/absent.json';
    await expectLater(
      readConfigFile(path),
      throwsA(
        isA<LocalizedFormatException>().having(
          (e) => e.text.resolve('fr'),
          'message',
          '$path : fichier introuvable',
        ),
      ),
    );
  });
}
