// BuildBeacon Hub — Plugin SDK: translated texts (i18n).
// Version 1.1 (2026-11-12) — comments in English.

/// Interface languages.
const supportedLanguages = ['en', 'fr'];

/// Language used when a text is not available in the requested language.
const fallbackLanguage = 'en';

/// User-facing text, in the interface languages.
///
/// - Fixed label: `const LocalizedText({'en': 'Repository', 'fr': 'Dépôt'})`.
/// - Message that contains values or other translated texts:
///   `LocalizedText.build((lang) => tr(lang, en: '…', fr: '…'))`, computed
///   in the reader's language when it is displayed.
abstract interface class LocalizedText {
  const factory LocalizedText(Map<String, String> translations) = _Translations;

  factory LocalizedText.build(String Function(String language) build) = _Built;

  /// Same text in every language (proper name, technical value).
  const factory LocalizedText.same(String text) = _Same;

  /// The text in [language] (`'fr'`, `'en'`…), otherwise in English.
  String resolve(String language);

  /// Languages the text is written in.
  Set<String> get languages;

  /// The text in each interface language: `{"en": "…", "fr": "…"}`.
  Map<String, String> toJson();
}

/// Picks the sentence for [language]; English for any other language.
String tr(String language, {required String en, required String fr}) =>
    language == 'fr' ? fr : en;

/// Interface language closest to [locale] (`fr_FR.UTF-8`, `fr-CA`, `en`…);
/// English if that language is not translated.
String languageOf(String? locale) {
  final code = (locale ?? '').toLowerCase();
  final prefix = code.length >= 2 ? code.substring(0, 2) : code;
  return supportedLanguages.contains(prefix) ? prefix : fallbackLanguage;
}

/// Format error (config.json, a service response…) with a translated
/// message; still a [FormatException] for the code that catches it.
final class LocalizedFormatException extends FormatException {
  LocalizedFormatException(this.text, [Object? source])
    : super(text.resolve(fallbackLanguage), source);

  final LocalizedText text;
}

extension LocalizedTexts on Iterable<LocalizedText> {
  /// Each text in [language].
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
