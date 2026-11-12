// BuildBeacon Hub — SDK tests: translated texts (i18n).
// Version 1.1 (2026-11-12) — comments in English.

import 'package:buildbeacon_plugin_sdk/buildbeacon_plugin_sdk.dart';
import 'package:test/test.dart';

void main() {
  const repository = LocalizedText({'en': 'Repository', 'fr': 'Dépôt'});

  test('libellé fixe : chaque langue, repli sur l\'anglais', () {
    expect(repository.resolve('fr'), 'Dépôt');
    expect(repository.resolve('en'), 'Repository');
    expect(repository.resolve('de'), 'Repository');
    expect(repository.languages, {'en', 'fr'});
  });

  test('sans anglais : repli sur la première langue écrite', () {
    expect(const LocalizedText({'fr': 'Dépôt'}).resolve('en'), 'Dépôt');
  });

  test('message calculé dans la langue du lecteur', () {
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

  test('même texte partout, et JSON pour l\'interface', () {
    expect(const LocalizedText.same('GitHub').resolve('fr'), 'GitHub');
    expect(repository.toJson(), {'en': 'Repository', 'fr': 'Dépôt'});
    expect([repository, const LocalizedText.same('x')].resolveAll('fr'), [
      'Dépôt',
      'x',
    ]);
  });

  test('langue d\'après une locale système ou navigateur', () {
    expect(languageOf('fr_FR.UTF-8'), 'fr');
    expect(languageOf('fr-CA'), 'fr');
    expect(languageOf('en_US'), 'en');
    expect(languageOf('de_DE'), 'en');
    expect(languageOf('C'), 'en');
    expect(languageOf(null), 'en');
  });

  test('erreur de format traduite, qui reste une FormatException', () {
    final error = LocalizedFormatException(
      const LocalizedText({'en': 'Missing field', 'fr': 'Champ manquant'}),
    );
    expect(error, isA<FormatException>());
    expect(error.message, 'Missing field');
    expect(error.text.resolve('fr'), 'Champ manquant');
  });

  test('libellés des états', () {
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
