// BuildBeacon Hub — Hub service: a single path to change the configuration (API, file).
// Version 1.1 (2026-11-12) — comments in English.

import 'dart:convert';
import 'dart:io';

import 'package:buildbeacon_core/buildbeacon_core.dart';

import 'config_file.dart';
import 'hub.dart';

/// Result of a proposed configuration.
sealed class ConfigResult {
  const ConfigResult();
}

/// Usable: applied if [changed] (otherwise identical to the current one).
final class ConfigAccepted extends ConfigResult {
  const ConfigAccepted(this.config, {required this.changed});

  final Config config;
  final bool changed;
}

/// Unreadable: invalid JSON or rejected format.
final class ConfigUnreadable extends ConfigResult {
  const ConfigUnreadable(this.error);

  final LocalizedText error;
}

/// Readable but inconsistent: nothing is applied.
final class ConfigRejected extends ConfigResult {
  const ConfigRejected(this.issues);

  final List<LocalizedText> issues;
}

/// Valid but impossible to save: nothing is applied, so that the Hub and
/// the file stay in agreement.
final class ConfigNotSaved extends ConfigResult {
  const ConfigNotSaved(this.error);

  final LocalizedText error;
}

/// Changes the configuration of the Hub in a single place, whether it comes
/// from the API or from the file edited by hand: reading, validation with
/// the plugins, saving, applying on the fly.
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

  /// Environment variables of the Hub. The API only reveals whether the
  /// secrets declared by the plugins are present, never their values.
  final Map<String, String> environment;

  final void Function(LocalizedText message) _log;
  final DateTime startedAt = DateTime.now();

  PluginRegistry get plugins => hub.plugins;

  /// Reads and validates [json] without applying anything.
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

  /// Validates [json], saves it to the file, then applies it to the Hub. A
  /// configuration identical to the current one is neither saved nor applied
  /// again.
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

  /// Rereads the file after a manual edit. An unreadable or invalid version
  /// is refused and the previous one kept; an identical version (for example
  /// the one the API has just saved) is ignored.
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
