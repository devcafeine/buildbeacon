// BuildBeacon Hub — Tests : lecture de config.json et premier démarrage.
// Version 1.0 (2026-11-12)

import 'dart:convert';
import 'dart:io';

import 'package:buildbeacon_core/buildbeacon_core.dart';
import 'package:buildbeacon_hub/buildbeacon_hub.dart';
import 'package:test/test.dart';

void main() {
  late Directory dir;

  setUp(() async => dir = await Directory.systemTemp.createTemp('bb-config'));
  tearDown(() => dir.delete(recursive: true));

  group('premier démarrage', () {
    test(
      'fichier absent : créé avec la master seule, dossier compris',
      () async {
        final path = '${dir.path}/data/config.json';
        final (:config, :created) = await readOrCreateConfigFile(path);

        expect(created, isTrue);
        expect(config.tiles.single.kind, TileKind.master);
        expect(config.validate(), isEmpty);
        // Le fichier écrit se relit tel quel.
        expect((await readConfigFile(path)).toJson(), config.toJson());
        expect(File('$path.tmp').existsSync(), isFalse);
      },
    );

    test('fichier présent : lu, pas recréé', () async {
      final path = '${dir.path}/config.json';
      final mine = Config.initial().toJson()..['poll_seconds'] = 300;
      File(path).writeAsStringSync(jsonEncode(mine));

      final (:config, :created) = await readOrCreateConfigFile(path);
      expect(created, isFalse);
      expect(config.pollSeconds, 300);
    });

    test('fichier illisible : erreur, jamais remplacé', () async {
      final path = '${dir.path}/config.json';
      File(path).writeAsStringSync('{ pas du JSON');

      await expectLater(
        readOrCreateConfigFile(path),
        throwsA(isA<LocalizedFormatException>()),
      );
      expect(File(path).readAsStringSync(), '{ pas du JSON');
    });

    test('chemin occupé par un dossier : erreur, rien de créé', () async {
      final path = '${dir.path}/config.json';
      Directory(path).createSync();
      await expectLater(
        readOrCreateConfigFile(path),
        throwsA(isA<LocalizedFormatException>()),
      );
    });
  });

  test('lecture : fichier absent signalé avec son chemin', () async {
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
