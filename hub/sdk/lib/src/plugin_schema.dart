// BuildBeacon Hub — Plugin SDK: settings, secrets and measurements of a plugin.
// Version 1.3 (2026-11-12) — comments in English.

import 'localized_text.dart';

/// Kind of a setting: used for validation and to pick the field shown in
/// the interface form.
enum SettingKind { text, integer, number, boolean, choice }

/// Setting of a source, entered in the interface and stored in config.json.
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

  /// Key in config.json (`"repo"`), in English. `type` is reserved.
  final String id;

  /// Label of the field in the interface.
  final LocalizedText label;

  final SettingKind kind;
  final bool required;

  /// Help text shown below the field.
  final LocalizedText? help;

  /// Example shown in the empty field (`owner/repo`).
  final String? placeholder;

  /// Regular expression that a text value must match in full.
  final String? pattern;

  /// Expected format, in plain words, shown when [pattern] does not match.
  final LocalizedText? patternHint;

  /// Allowed values when [kind] is [SettingKind.choice].
  final List<String> choices;

  /// Problems with [value]; `null` = setting missing.
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

/// Secret the plugin needs (token, access code). Provided by an environment
/// variable: never written to config.json nor returned by the API.
final class SecretField {
  const SecretField({
    required this.env,
    required this.label,
    this.required = false,
    this.help,
  });

  /// Environment variable name, prefixed with `BB_` (`BB_GITHUB_TOKEN`).
  final String env;
  final LocalizedText label;

  /// Without this secret, the Hub does not open the source.
  final bool required;
  final LocalizedText? help;

  Map<String, Object?> toJson() => {
    'env': env,
    'label': label.toJson(),
    'required': required,
    if (help != null) 'help': help!.toJson(),
  };
}

/// Numeric measurement a plugin can provide (thresholds and gauge modes).
final class MetricInfo {
  const MetricInfo({
    required this.id,
    required this.label,
    this.unit,
    this.min,
    this.max,
  });

  /// Identifier, in English, used in the `metric` option of an action.
  final String id;
  final LocalizedText label;
  final String? unit;

  /// Natural bounds (0 – 100 for a percentage).
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
