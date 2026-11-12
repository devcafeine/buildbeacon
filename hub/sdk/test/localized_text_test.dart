// BuildBeacon Hub — SDK tests: translated texts (i18n).
// Version 1.2 (2026-11-12) — test names in English.

import 'package:buildbeacon_plugin_sdk/buildbeacon_plugin_sdk.dart';
import 'package:test/test.dart';

void main() {
  const repository = LocalizedText({'en': 'Repository', 'fr': 'Dépôt'});

  test('fixed label: each language, English fallback', () {
    expect(repository.resolve('fr'), 'Dépôt');
    expect(repository.resolve('en'), 'Repository');
    expect(repository.resolve('de'), 'Repository');
    expect(repository.languages, {'en', 'fr'});
  });

  test('no English: falls back to the first language given', () {
    expect(const LocalizedText({'fr': 'Dépôt'}).resolve('en'), 'Dépôt');
  });

  test('computed message in the reader\'s language', () {
    final message = LocalizedText.build(
      (l) => tr(
        l,
        en: '"${repository.resolve(l)}" is required',
        fr: '« ${repository.resolve(l)} » est obligatoire',
      ),
    );
    expect(message.resolve('fr'), '« Dépôt » est obligatoire');
    expect(message.resolve('en'), '"Repository" is required');
    expect(message.toString(), '"Repository" is required');
  });

  test('same text everywhere, and JSON for the UI', () {
    expect(const LocalizedText.same('GitHub').resolve('fr'), 'GitHub');
    expect(repository.toJson(), {'en': 'Repository', 'fr': 'Dépôt'});
    expect([repository, const LocalizedText.same('x')].resolveAll('fr'), [
      'Dépôt',
      'x',
    ]);
  });

  test('language from a system or browser locale', () {
    expect(languageOf('fr_FR.UTF-8'), 'fr');
    expect(languageOf('fr-CA'), 'fr');
    expect(languageOf('en_US'), 'en');
    expect(languageOf('de_DE'), 'en');
    expect(languageOf('C'), 'en');
    expect(languageOf(null), 'en');
  });

  test('translated format error, still a FormatException', () {
    final error = LocalizedFormatException(
      const LocalizedText({'en': 'Missing field', 'fr': 'Champ manquant'}),
    );
    expect(error, isA<FormatException>());
    expect(error.message, 'Missing field');
    expect(error.text.resolve('fr'), 'Champ manquant');
  });

  test('status labels', () {
    expect(Status.running.label.resolve('fr'), 'en cours');
    expect(Status.running.label.resolve('en'), 'running');
    expect(Status.values.map((s) => s.json), [
      'success',
      'warning',
      'failure',
      'running',
      'queued',
      'cancelled',
      'unknown',
    ]);
  });
}
