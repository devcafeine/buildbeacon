// BuildBeacon Hub — SDK tests: typed access to settings.
// Version 1.3 (2026-11-12) — test names in English.

import 'package:buildbeacon_plugin_sdk/buildbeacon_plugin_sdk.dart';
import 'package:test/test.dart';

void main() {
  final settings = SourceSettings({
    'repo': 'acme/app',
    'port': 8883,
    'threshold': 2,
    'tls': true,
  });

  test('reads each type', () {
    expect(settings.text('repo'), 'acme/app');
    expect(settings.integer('port'), 8883);
    expect(settings.number('threshold'), 2.0);
    expect(settings.flag('tls'), isTrue);
  });

  test('missing optional settings: null or default value', () {
    expect(settings.optionalText('branch'), isNull);
    expect(settings.optionalInteger('delay'), isNull);
    expect(settings.optionalNumber('margin'), isNull);
    expect(settings.flag('verbose'), isFalse);
    expect(settings.flag('verbose', orElse: true), isTrue);
  });

  test('missing required setting: plugin error, explicit message', () {
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

  test('wrong type: plugin error', () {
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

  test('raw values are unmodifiable', () {
    expect(() => settings.values['repo'] = 'x', throwsUnsupportedError);
  });
}
