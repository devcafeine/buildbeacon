// BuildBeacon Hub — SDK des plugins : contrat d'un plugin de source.
// Version 1.2 (2026-11-11) — libellés et messages traduits (LocalizedText).

import 'package:http/http.dart' as http;

import 'localized_text.dart';
import 'plugin_schema.dart';
import 'source_settings.dart';
import 'source_state.dart';

/// Plugin de source : tout ce que le Hub sait d'une intégration (GitHub,
/// imprimante 3D, ping HTTP…).
///
/// Un plugin décrit ses réglages, ses secrets et ce qu'il fournit
/// (historique, mesures), puis produit un flux d'états avec [connect]. Le Hub
/// s'occupe du reste : une seule connexion par source distincte, cache,
/// rendu, formulaires de l'interface. Les textes destinés à l'utilisateur
/// sont des [LocalizedText] : le plugin apporte ses traductions.
abstract class SourcePlugin {
  const SourcePlugin();

  /// Identifiant stable, utilisé dans config.json (`"type": "github"`) :
  /// minuscules, chiffres et `_`, en anglais.
  String get type;

  /// Nom affiché dans l'interface.
  LocalizedText get label;

  /// Une phrase d'explication pour l'interface.
  LocalizedText get description;

  /// Réglages d'une source de ce type.
  List<SettingField> get settings;

  /// Secrets lus dans l'environnement. Le plugin ne reçoit que ceux-ci.
  List<SecretField> get secrets => const [];

  /// Le plugin remplit [SourceState.history] (mode history).
  bool get providesHistory => false;

  /// Mesures que le plugin peut fournir (modes thresholds et gauge).
  List<MetricInfo> get metrics => const [];

  /// Mesures non connues d'avance (plugin générique, nommées par
  /// l'utilisateur) : le Hub ne vérifie alors pas l'option `metric`.
  bool get dynamicMetrics => false;

  /// Contrôles propres au plugin, en plus de ceux de chaque champ
  /// (cohérence entre réglages…).
  ///
  /// Appelé seulement quand chaque champ est valide : les accesseurs typés
  /// de [settings] sont sûrs.
  List<LocalizedText> validateSettings(SourceSettings settings) => const [];

  /// Ouvre la source décrite par [settings], déjà validés. Le flux émet un
  /// état à chaque changement ; le Hub l'annule quand la source ne sert plus.
  ///
  /// Pour une source scrutée, voir `pollingStream`.
  Stream<SourceState> connect(SourceSettings settings, PluginContext context);

  /// Description du plugin pour l'interface, qui en génère les formulaires.
  /// Les textes y figurent dans chaque langue de l'interface.
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

/// Ce que le Hub met à la disposition d'un plugin.
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

  /// Client HTTP partagé par tous les plugins (connexions réutilisées).
  final http.Client httpClient;

  /// Intervalle de scrutation réglé par l'utilisateur.
  final Duration pollInterval;

  /// Horloge, remplaçable dans les tests.
  final DateTime Function() now;

  final Map<String, String> _secrets;
  final void Function(String message) _log;

  /// Valeur du secret [env] s'il est défini. Seuls les secrets déclarés par
  /// le plugin lui sont transmis.
  String? secret(String env) => _secrets[env];

  /// Message technique pour le journal du Hub (en anglais), préfixé par le
  /// type du plugin.
  void log(String message) => _log(message);

  static void _silent(String message) {}
}

/// Erreur de lecture d'une source, avec un message traduit pour
/// l'utilisateur (affiché dans l'interface).
final class SourceException implements Exception {
  const SourceException(this.message);

  final LocalizedText message;

  @override
  String toString() => message.resolve(fallbackLanguage);
}
