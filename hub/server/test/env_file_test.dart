// BuildBeacon Hub — Tests: reading the .env file.
// Version 1.2 (2026-11-12) — test names in English.

import 'dart:io';

import 'package:buildbeacon_hub/buildbeacon_hub.dart';
import 'package:test/test.dart';

void main() {
  test('NAME=value lines, comments, quotes, export', () {
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
    'the process environment takes precedence, empty values ignored',
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

  test('missing .env file: only the process environment', () async {
    final env = await loadEnvironment(
      envFile: '/nowhere/.env',
      processEnvironment: {'A': '1'},
    );
    expect(env, {'A': '1'});
  });
}
