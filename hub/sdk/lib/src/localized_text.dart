// BuildBeacon Hub — SDK des plugins : textes traduits (i18n).
// Version 1.0 (2026-11-11)

/// Langues de l'interface.
const supportedLanguages = ['en', 'fr'];

/// Langue utilisée quand un texte n'existe pas dans la langue demandée.
const fallbackLanguage = 'en';

/// Texte destiné à l'utilisateur, dans les langues de l'interface.
///
/// - Libellé fixe : `const LocalizedText({'en': 'Repository', 'fr': 'Dépôt'})`.
/// - Message qui contient des valeurs ou d'autres textes traduits :
///   `LocalizedText.build((lang) => tr(lang, en: '…', fr: '…'))`, calculé
///   dans la langue du lecteur au moment de l'affichage.
abstract interface class LocalizedText {
  const factory LocalizedText(Map<String, String> translations) = _Translations;

  factory LocalizedText.build(String Function(String language) build) = _Built;

  /// Même texte dans toutes les langues (nom propre, valeur technique).
  const factory LocalizedText.same(String text) = _Same;

  /// Le texte en [language] (`'fr'`, `'en'`…), sinon en anglais.
  String resolve(String language);

  /// Langues dans lesquelles le texte est écrit.
  Set<String> get languages;

  /// Le texte dans chaque langue de l'interface : `{"en": "…", "fr": "…"}`.
  Map<String, String> toJson();
}

/// Choisit la phrase de [language] ; l'anglais pour toute autre langue.
String tr(String language, {required String en, required String fr}) =>
    language == 'fr' ? fr : en;

/// Langue de l'interface la plus proche de [locale] (`fr_FR.UTF-8`, `fr-CA`,
/// `en`…) ; l'anglais si elle n'est pas traduite.
String languageOf(String? locale) {
  final code = (locale ?? '').toLowerCase();
  final prefix = code.length >= 2 ? code.substring(0, 2) : code;
  return supportedLanguages.contains(prefix) ? prefix : fallbackLanguage;
}

/// Erreur de format (config.json, réponse d'un service…) avec un message
/// traduit ; reste une [FormatException] pour le code qui l'attrape.
final class LocalizedFormatException extends FormatException {
  LocalizedFormatException(this.text, [Object? source])
    : super(text.resolve(fallbackLanguage), source);

  final LocalizedText text;
}

extension LocalizedTexts on Iterable<LocalizedText> {
  /// Chaque texte dans [language].
  List<String> resolveAll(String language) => [
    for (final text in this) text.resolve(language),
  ];
}

abstract class _Base implements LocalizedText {
  const _Base();

  @override
  Map<String, String> toJson() => {
    for (final language in supportedLanguages) language: resolve(language),
  };

  @override
  String toString() => resolve(fallbackLanguage);
}

final class _Translations extends _Base {
  const _Translations(this._translations);

  final Map<String, String> _translations;

  @override
  String resolve(String language) =>
      _translations[language] ??
      _translations[fallbackLanguage] ??
      _translations.values.firstOrNull ??
      '';

  @override
  Set<String> get languages => _translations.keys.toSet();
}

final class _Built extends _Base {
  _Built(this._build);

  final String Function(String language) _build;

  @override
  String resolve(String language) => _build(language);

  @override
  Set<String> get languages => supportedLanguages.toSet();
}

final class _Same extends _Base {
  const _Same(this._text);

  final String _text;

  @override
  String resolve(String language) => _text;

  @override
  Set<String> get languages => supportedLanguages.toSet();
}
