// BuildBeacon Hub — Plugin SDK: contract of a source plugin.
// Version 1.3 (2026-11-12) — comments in English.

import 'package:http/http.dart' as http;

import 'localized_text.dart';
import 'plugin_schema.dart';
import 'source_settings.dart';
import 'source_state.dart';

/// Source plugin: everything the Hub knows about an integration (GitHub,
/// 3D printer, HTTP ping…).
///
/// A plugin describes its settings, its secrets and what it provides
/// (history, measurements), then produces a stream of states with [connect].
/// The Hub takes care of the rest: a single connection per distinct source,
/// caching, rendering, interface forms. User-facing texts are
/// [LocalizedText]: the plugin brings its own translations.
abstract class SourcePlugin {
  const SourcePlugin();

  /// Stable identifier, used in config.json (`"type": "github"`): lowercase
  /// letters, digits and `_`, in English.
  String get type;

  /// Name shown in the interface.
  LocalizedText get label;

  /// One sentence of explanation for the interface.
  LocalizedText get description;

  /// Settings of a source of this type.
  List<SettingField> get settings;

  /// Secrets read from the environment. The plugin receives only these.
  List<SecretField> get secrets => const [];

  /// The plugin fills [SourceState.history] (history mode).
  bool get providesHistory => false;

  /// Measurements the plugin can provide (thresholds and gauge modes).
  List<MetricInfo> get metrics => const [];

  /// Measurements not known in advance (generic plugin, named by the
  /// user): the Hub then does not check the `metric` option.
  bool get dynamicMetrics => false;

  /// Plugin-specific checks, on top of the checks of each field
  /// (consistency between settings…).
  ///
  /// Called only when every field is valid: the typed accessors of
  /// [settings] are safe to use.
  List<LocalizedText> validateSettings(SourceSettings settings) => const [];

  /// Opens the source described by [settings], already validated. The stream
  /// emits a state on each change; the Hub cancels it when the source is no
  /// longer used.
  ///
  /// For a polled source, see `pollingStream`.
  Stream<SourceState> connect(SourceSettings settings, PluginContext context);

  /// Description of the plugin for the interface, which generates its forms
  /// from it. Texts appear in every interface language.
  Map<String, Object?> describe() => {
    'type': type,
    'label': label.toJson(),
    'description': description.toJson(),
    'settings': [for (final s in settings) s.toJson()],
    'secrets': [for (final s in secrets) s.toJson()],
    'provides_history': providesHistory,
    'metrics': [for (final m in metrics) m.toJson()],
    'dynamic_metrics': dynamicMetrics,
  };
}

/// What the Hub makes available to a plugin.
final class PluginContext {
  PluginContext({
    required this.httpClient,
    required this.pollInterval,
    Map<String, String> secrets = const {},
    void Function(String message)? log,
    DateTime Function()? clock,
  }) : _secrets = Map.unmodifiable(secrets),
       _log = log ?? _silent,
       now = clock ?? DateTime.now;

  /// HTTP client shared by all plugins (connections are reused).
  final http.Client httpClient;

  /// Polling interval set by the user.
  final Duration pollInterval;

  /// Clock, replaceable in tests.
  final DateTime Function() now;

  final Map<String, String> _secrets;
  final void Function(String message) _log;

  /// Value of the secret [env], if set. Only the secrets declared by the
  /// plugin are passed to it.
  String? secret(String env) => _secrets[env];

  /// Technical message for the Hub log (in English), prefixed with the
  /// plugin type.
  void log(String message) => _log(message);

  static void _silent(String message) {}
}

/// Error while reading a source, with a translated message for the user
/// (shown in the interface).
final class SourceException implements Exception {
  const SourceException(this.message);

  final LocalizedText message;

  @override
  String toString() => message.resolve(fallbackLanguage);
}
