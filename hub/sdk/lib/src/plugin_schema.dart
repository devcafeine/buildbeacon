// BuildBeacon Hub — SDK des plugins : réglages, secrets et mesures d'un plugin.
// Version 1.2 (2026-11-11) — libellés, aides et messages traduits (LocalizedText).

import 'localized_text.dart';

/// Type d'un réglage : sert à la validation et au choix du champ dans
/// le formulaire de l'interface.
enum SettingKind { text, integer, number, boolean, choice }

/// Réglage d'une source, saisi dans l'interface et stocké dans config.json.
final class SettingField {
  const SettingField({
    required this.id,
    required this.label,
    this.kind = SettingKind.text,
    this.required = false,
    this.help,
    this.placeholder,
    this.pattern,
    this.patternHint,
    this.choices = const [],
  });

  /// Clé dans config.json (`"repo"`), en anglais. `type` est réservé.
  final String id;

  /// Libellé du champ dans l'interface.
  final LocalizedText label;

  final SettingKind kind;
  final bool required;

  /// Aide affichée sous le champ.
  final LocalizedText? help;

  /// Exemple affiché dans le champ vide (`owner/repo`).
  final String? placeholder;

  /// Expression régulière que doit respecter un texte, en entier.
  final String? pattern;

  /// Format attendu, en clair, affiché quand [pattern] n'est pas respecté.
  final LocalizedText? patternHint;

  /// Valeurs permises quand [kind] vaut [SettingKind.choice].
  final List<String> choices;

  /// Problèmes de [value] ; `null` = réglage absent.
  List<LocalizedText> validate(Object? value) {
    if (value == null) {
      return [
        if (required)
          LocalizedText.build(
            (l) => tr(
              l,
              en: '"${label.resolve(l)}" is required',
              fr: '« ${label.resolve(l)} » est obligatoire',
            ),
          ),
      ];
    }
    final typeOk = switch (kind) {
      SettingKind.text || SettingKind.choice => value is String,
      SettingKind.integer => value is int,
      SettingKind.number => value is num,
      SettingKind.boolean => value is bool,
    };
    if (!typeOk) {
      return [
        LocalizedText.build(
          (l) => tr(
            l,
            en: '"${label.resolve(l)}": ${_expected(l)} expected',
            fr: '« ${label.resolve(l)} » : ${_expected(l)} attendu',
          ),
        ),
      ];
    }
    return [
      if (kind == SettingKind.choice && !choices.contains(value))
        LocalizedText.build(
          (l) => tr(
            l,
            en:
                '"${label.resolve(l)}": unknown value "$value" '
                '(${choices.join(', ')})',
            fr:
                '« ${label.resolve(l)} » : « $value » inconnu '
                '(${choices.join(', ')})',
          ),
        ),
      if (pattern case final p?
          when value is String && !RegExp('^(?:$p)\$').hasMatch(value))
        LocalizedText.build((l) {
          final hint = patternHint?.resolve(l);
          return tr(
            l,
            en:
                '"${label.resolve(l)}" is invalid: "$value"'
                '${hint == null ? '' : ' (expected: $hint)'}',
            fr:
                '« ${label.resolve(l)} » invalide : « $value »'
                '${hint == null ? '' : ' ($hint attendu)'}',
          );
        }),
    ];
  }

  String _expected(String l) => switch (kind) {
    SettingKind.text || SettingKind.choice => tr(l, en: 'text', fr: 'un texte'),
    SettingKind.integer => tr(l, en: 'an integer', fr: 'un nombre entier'),
    SettingKind.number => tr(l, en: 'a number', fr: 'un nombre'),
    SettingKind.boolean => tr(l, en: 'yes or no', fr: 'oui ou non'),
  };

  Map<String, Object?> toJson() => {
    'id': id,
    'label': label.toJson(),
    'kind': kind.name,
    'required': required,
    if (help != null) 'help': help!.toJson(),
    if (placeholder != null) 'placeholder': placeholder,
    if (pattern != null) 'pattern': pattern,
    if (patternHint != null) 'pattern_hint': patternHint!.toJson(),
    if (choices.isNotEmpty) 'choices': choices,
  };
}

/// Secret dont le plugin a besoin (jeton, code d'accès). Fourni par une
/// variable d'environnement : jamais écrit dans config.json ni renvoyé par
/// l'API.
final class SecretField {
  const SecretField({
    required this.env,
    required this.label,
    this.required = false,
    this.help,
  });

  /// Nom de la variable d'environnement, préfixé `BB_` (`BB_GITHUB_TOKEN`).
  final String env;
  final LocalizedText label;

  /// Sans ce secret, le Hub n'ouvre pas la source.
  final bool required;
  final LocalizedText? help;

  Map<String, Object?> toJson() => {
    'env': env,
    'label': label.toJson(),
    'required': required,
    if (help != null) 'help': help!.toJson(),
  };
}

/// Mesure chiffrée qu'un plugin peut fournir (modes seuils et jauge).
final class MetricInfo {
  const MetricInfo({
    required this.id,
    required this.label,
    this.unit,
    this.min,
    this.max,
  });

  /// Identifiant en anglais, utilisé dans l'option `metric` d'une action.
  final String id;
  final LocalizedText label;
  final String? unit;

  /// Bornes naturelles (0 – 100 pour un pourcentage).
  final double? min;
  final double? max;

  Map<String, Object?> toJson() => {
    'id': id,
    'label': label.toJson(),
    if (unit != null) 'unit': unit,
    if (min != null) 'min': min,
    if (max != null) 'max': max,
  };
}
