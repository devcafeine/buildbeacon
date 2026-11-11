// BuildBeacon Hub — Tests SDK : accès typé aux réglages.
// Version 1.1 (2026-11-11) — messages d'erreur de programmation en anglais.

import 'package:buildbeacon_plugin_sdk/buildbeacon_plugin_sdk.dart';
import 'package:test/test.dart';

void main() {
  final settings = SourceSettings({
    'repo': 'acme/app',
    'port': 8883,
    'threshold': 2,
    'tls': true,
  });

  test('lit chaque type', () {
    expect(settings.text('repo'), 'acme/app');
    expect(settings.integer('port'), 8883);
    expect(settings.number('threshold'), 2.0);
    expect(settings.flag('tls'), isTrue);
  });

  test('réglages facultatifs absents : null ou valeur par défaut', () {
    expect(settings.optionalText('branch'), isNull);
    expect(settings.optionalInteger('delay'), isNull);
    expect(settings.optionalNumber('margin'), isNull);
    expect(settings.flag('verbose'), isFalse);
    expect(settings.flag('verbose', orElse: true), isTrue);
  });

  test('réglage obligatoire absent : erreur du plugin, message explicite', () {
    expect(
      () => settings.text('branch'),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('declare it as required'),
        ),
      ),
    );
  });

  test('mauvais type : erreur du plugin', () {
    expect(
      () => settings.text('port'),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          'Setting "port": text expected, found "8883"',
        ),
      ),
    );
    expect(() => settings.optionalInteger('repo'), throwsStateError);
  });

  test('valeurs brutes non modifiables', () {
    expect(() => settings.values['repo'] = 'x', throwsUnsupportedError);
  });
}
