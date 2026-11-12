// BuildBeacon Hub — Plugin SDK: settings validation and conformance.
// Version 1.2 (2026-11-12) — comments in English.

import 'dart:convert';

import 'localized_text.dart';
import 'plugin_schema.dart';
import 'source_plugin.dart';
import 'source_settings.dart';

final _identifier = RegExp(r'^[a-z][a-z0-9_]*$');
final _envName = RegExp(r'^BB_[A-Z0-9_]+$');

/// Problems with the settings [values] of a [plugin] source: missing required
/// field, wrong type, format, choice, unknown setting (typo), then the
/// plugin-specific checks. Translated messages; empty if everything is fine.
/// This is the validation the Hub applies.
List<LocalizedText> settingsIssues(
  SourcePlugin plugin,
  Map<String, Object?> values,
) {
  final known = {for (final field in plugin.settings) field.id};
  final fieldIssues = [
    for (final field in plugin.settings) ...field.validate(values[field.id]),
    for (final key in values.keys)
      if (!known.contains(key))
        LocalizedText.build(
          (l) => tr(
            l,
            en: 'unknown setting "$key" for ${plugin.label.resolve(l)}',
            fr: 'réglage inconnu « $key » pour ${plugin.label.resolve(l)}',
          ),
        ),
  ];
  // The plugin checks assume valid fields.
  if (fieldIssues.isNotEmpty) return fieldIssues;
  return plugin.validateSettings(SourceSettings(values));
}

/// Checks that a plugin follows the Hub rules, without running it:
/// identifiers, settings, secrets, measurements, English translations, JSON
/// description. Messages in English, for developers.
///
/// The Hub rejects a non-conforming plugin. In a plugin's tests:
/// `expect(conformanceIssues(const MyPlugin()), isEmpty);`
List<String> conformanceIssues(SourcePlugin plugin) => [
  if (!_identifier.hasMatch(plugin.type))
    'type "${plugin.type}": lowercase letters, digits and _, '
        'starting with a letter',
  ..._textIssues('label', plugin.label),
  ..._textIssues('description', plugin.description),
  ..._duplicates('setting', [for (final s in plugin.settings) s.id]),
  for (final setting in plugin.settings) ..._settingIssues(setting),
  ..._duplicates('secret', [for (final s in plugin.secrets) s.env]),
  for (final secret in plugin.secrets) ...[
    if (!_envName.hasMatch(secret.env))
      'secret "${secret.env}": uppercase variable name prefixed with BB_',
    ..._textIssues('secret "${secret.env}" label', secret.label),
  ],
  ..._duplicates('metric', [for (final m in plugin.metrics) m.id]),
  for (final metric in plugin.metrics) ...[
    if (!_identifier.hasMatch(metric.id))
      'metric "${metric.id}": lowercase letters, digits and _',
    ..._textIssues('metric "${metric.id}" label', metric.label),
    if ((metric.min, metric.max) case (final min?, final max?) when min >= max)
      'metric "${metric.id}": min ($min) must be lower than max ($max)',
  ],
  ..._describeIssues(plugin),
];

/// A text must exist in English (the fallback language) and not be empty.
List<String> _textIssues(String what, LocalizedText text) => [
  if (!text.languages.contains(fallbackLanguage))
    '$what: English translation missing',
  if (text.resolve(fallbackLanguage).trim().isEmpty) '$what: empty',
];

List<String> _settingIssues(SettingField setting) => [
  if (setting.id == 'type')
    'setting "type": reserved name'
  else if (!_identifier.hasMatch(setting.id))
    'setting "${setting.id}": lowercase letters, digits and _ '
        '(it is a config.json key)',
  ..._textIssues('setting "${setting.id}" label', setting.label),
  if (setting.kind == SettingKind.choice && setting.choices.isEmpty)
    'setting "${setting.id}": choice kind without choices',
  if (setting.kind != SettingKind.choice && setting.choices.isNotEmpty)
    'setting "${setting.id}": choices require the choice kind',
  if (setting.pattern case final pattern?) ...[
    if (setting.kind != SettingKind.text)
      'setting "${setting.id}": pattern requires the text kind',
    if (!_compiles(pattern))
      'setting "${setting.id}": invalid pattern "$pattern"',
  ],
];

bool _compiles(String pattern) {
  try {
    RegExp(pattern);
    return true;
  } on FormatException {
    return false;
  }
}

List<String> _describeIssues(SourcePlugin plugin) {
  try {
    jsonEncode(plugin.describe());
    return const [];
  } catch (e) {
    return ['describe() cannot be converted to JSON: $e'];
  }
}

List<String> _duplicates(String what, List<String> ids) {
  final seen = <String>{};
  final reported = <String>{};
  return [
    for (final id in ids)
      if (!seen.add(id) && reported.add(id)) '$what "$id" declared twice',
  ];
}
