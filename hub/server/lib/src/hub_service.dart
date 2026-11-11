// BuildBeacon Hub — Service du Hub : un seul chemin pour changer la configuration (API, fichier).
// Version 1.0 (2026-11-11)

import 'dart:convert';
import 'dart:io';

import 'package:buildbeacon_core/buildbeacon_core.dart';

import 'config_file.dart';
import 'hub.dart';

/// Résultat d'une configuration proposée.
sealed class ConfigResult {
  const ConfigResult();
}

/// Utilisable : appliquée si [changed] (identique à celle en cours sinon).
final class ConfigAccepted extends ConfigResult {
  const ConfigAccepted(this.config, {required this.changed});

  final Config config;
  final bool changed;
}

/// Illisible : JSON invalide ou format refusé.
final class ConfigUnreadable extends ConfigResult {
  const ConfigUnreadable(this.error);

  final LocalizedText error;
}

/// Lisible mais incohérente : rien n'est appliqué.
final class ConfigRejected extends ConfigResult {
  const ConfigRejected(this.issues);

  final List<LocalizedText> issues;
}

/// Valide mais impossible à enregistrer : rien n'est appliqué, pour que le
/// Hub et le fichier restent d'accord.
final class ConfigNotSaved extends ConfigResult {
  const ConfigNotSaved(this.error);

  final LocalizedText error;
}

/// Change la configuration du Hub en un seul endroit, qu'elle vienne de
/// l'API ou du fichier modifié à la main : lecture, validation avec les
/// plugins, enregistrement, application à chaud.
final class HubService {
  HubService({
    required this.hub,
    required this.configPath,
    Map<String, String> environment = const {},
    void Function(LocalizedText message)? log,
  }) : environment = Map.unmodifiable(environment),
       _log = log ?? _silent;

  final Hub hub;
  final String configPath;

  /// Variables d'environnement du Hub. L'API n'en révèle que la présence des
  /// secrets déclarés par les plugins, jamais les valeurs.
  final Map<String, String> environment;

  final void Function(LocalizedText message) _log;
  final DateTime startedAt = DateTime.now();

  PluginRegistry get plugins => hub.plugins;

  /// Lit et valide [json] sans rien appliquer.
  ConfigResult validate(Object? json) {
    if (json is! Map<String, Object?>) {
      return const ConfigUnreadable(
        LocalizedText({
          'en': 'a JSON object is expected',
          'fr': 'un objet JSON est attendu',
        }),
      );
    }
    final Config config;
    try {
      config = Config.fromJson(json);
    } on LocalizedFormatException catch (e) {
      return ConfigUnreadable(e.text);
    } on FormatException catch (e) {
      return ConfigUnreadable(LocalizedText.same(e.message));
    }
    final issues = config.validate(plugins: plugins);
    if (issues.isNotEmpty) return ConfigRejected(issues);
    return ConfigAccepted(config, changed: !_isCurrent(config));
  }

  /// Valide [json], l'enregistre dans le fichier puis l'applique au Hub. Une
  /// configuration identique à celle en cours n'est ni réenregistrée ni
  /// réappliquée.
  Future<ConfigResult> update(Object? json) async {
    final result = validate(json);
    if (result is! ConfigAccepted || !result.changed) return result;
    try {
      await writeConfigFile(configPath, result.config);
    } on FileSystemException catch (e) {
      final reason = e.osError?.message ?? e.message;
      return ConfigNotSaved(
        LocalizedText.build(
          (l) => tr(
            l,
            en: 'cannot save $configPath: $reason',
            fr: 'impossible d\'enregistrer $configPath : $reason',
          ),
        ),
      );
    }
    await _apply(result.config);
    _log(
      const LocalizedText({
        'en': 'Configuration changed through the API and saved',
        'fr': 'Configuration modifiée par l\'API et enregistrée',
      }),
    );
    return result;
  }

  /// Relit le fichier après une modification à la main. Une version
  /// illisible ou invalide est refusée et la précédente gardée ; une version
  /// identique (par exemple celle que l'API vient d'enregistrer) est ignorée.
  Future<void> reloadFromDisk() async {
    final Config next;
    try {
      next = await readConfigFile(configPath);
    } on LocalizedFormatException catch (e) {
      _log(
        LocalizedText.build(
          (l) => tr(
            l,
            en: '${e.text.resolve(l)} — the previous configuration is kept',
            fr: '${e.text.resolve(l)} — la configuration précédente est gardée',
          ),
        ),
      );
      return;
    }
    if (_isCurrent(next)) return;
    final issues = next.validate(plugins: plugins);
    if (issues.isNotEmpty) {
      _log(
        const LocalizedText({
          'en': 'New configuration refused, the previous one is kept:',
          'fr': 'Nouvelle configuration refusée, la précédente est gardée :',
        }),
      );
      for (final issue in issues) {
        _log(LocalizedText.build((l) => '  - ${issue.resolve(l)}'));
      }
      return;
    }
    await _apply(next);
    _log(
      const LocalizedText({
        'en': 'Configuration reloaded',
        'fr': 'Configuration rechargée',
      }),
    );
  }

  Future<void> _apply(Config config) async {
    await hub.apply(config);
    if (githubQuotaWarning(config, environment) case final warning?) {
      _log(warning);
    }
  }

  bool _isCurrent(Config config) =>
      jsonEncode(config.toJson()) == jsonEncode(hub.config.toJson());

  static void _silent(LocalizedText message) {}
}
