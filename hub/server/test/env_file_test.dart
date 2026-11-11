// BuildBeacon Hub — Tests : lecture du fichier .env.
// Version 1.0 (2026-11-11)

import 'dart:io';

import 'package:buildbeacon_hub/buildbeacon_hub.dart';
import 'package:test/test.dart';

void main() {
  test('lignes NOM=valeur, commentaires, guillemets, export', () {
    final values = parseEnvFile('''
# Jeton GitHub
BB_GITHUB_TOKEN=github_pat_abc
export BB_LANG=fr
QUOTED="a value # not a comment"
SINGLE='x'
WITH_COMMENT=value # comment
EMPTY=
not a line
1BAD=x
''');
    expect(values, {
      'BB_GITHUB_TOKEN': 'github_pat_abc',
      'BB_LANG': 'fr',
      'QUOTED': 'a value # not a comment',
      'SINGLE': 'x',
      'WITH_COMMENT': 'value',
      'EMPTY': '',
    });
  });

  test(
    'l\'environnement du processus a priorité, valeurs vides ignorées',
    () async {
      final dir = await Directory.systemTemp.createTemp('bb-env');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/.env')
        ..writeAsStringSync(
          'BB_GITHUB_TOKEN=\nBB_LANG=fr\nBB_CONFIG=/data/a.json\n',
        );

      final env = await loadEnvironment(
        envFile: file.path,
        processEnvironment: {'BB_CONFIG': '/tmp/b.json'},
      );
      expect(env, {'BB_LANG': 'fr', 'BB_CONFIG': '/tmp/b.json'});
    },
  );

  test(
    'fichier .env absent : seulement l\'environnement du processus',
    () async {
      final env = await loadEnvironment(
        envFile: '/nowhere/.env',
        processEnvironment: {'A': '1'},
      );
      expect(env, {'A': '1'});
    },
  );
}
