// BuildBeacon Hub — SDK des plugins : banc d'essai pour les tests de plugin.
// Version 1.1 (2026-11-11) — messages pour développeurs en anglais.

import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../localized_text.dart';
import '../source_plugin.dart';
import '../source_settings.dart';
import '../source_state.dart';
import '../validation.dart';

/// Réponse simulée d'un service HTTP.
typedef FakeHttpHandler =
    FutureOr<http.Response> Function(http.Request request);

/// Contexte de test : HTTP simulé par [respond] (sans lui, toute requête
/// échoue), secrets, intervalle de scrutation et horloge.
///
/// L'intervalle par défaut (1 h) garantit une seule lecture pendant un test ;
/// le réduire pour observer plusieurs lectures avec [firstStates].
PluginContext fakeContext({
  FakeHttpHandler? respond,
  Map<String, String> secrets = const {},
  Duration pollInterval = const Duration(hours: 1),
  DateTime Function()? clock,
  void Function(String message)? log,
}) => PluginContext(
  httpClient: MockClient((request) async {
    if (respond == null) {
      throw StateError(
        'unexpected HTTP request: ${request.method} ${request.url}',
      );
    }
    return respond(request);
  }),
  pollInterval: pollInterval,
  secrets: secrets,
  clock: clock,
  log: log,
);

/// Ouvre [plugin] avec [settings], comme le ferait le Hub, et renvoie le
/// premier état émis.
///
/// Les réglages sont d'abord validés : s'ils ne le sont pas, lève une
/// [ArgumentError] qui liste les problèmes.
Future<SourceState> firstState(
  SourcePlugin plugin,
  Map<String, Object?> settings, {
  PluginContext? context,
  Duration timeout = const Duration(seconds: 5),
}) async => (await firstStates(
  plugin,
  settings,
  1,
  context: context,
  timeout: timeout,
)).single;

/// Les [count] premiers états émis par [plugin] (voir [firstState]). Avec
/// une source scrutée, réduire `pollInterval` dans [context].
Future<List<SourceState>> firstStates(
  SourcePlugin plugin,
  Map<String, Object?> settings,
  int count, {
  PluginContext? context,
  Duration timeout = const Duration(seconds: 5),
}) {
  final issues = settingsIssues(plugin, settings);
  if (issues.isNotEmpty) {
    throw ArgumentError(
      'Invalid settings for "${plugin.type}": '
      '${issues.resolveAll(fallbackLanguage).join('; ')}',
    );
  }
  return plugin
      .connect(SourceSettings(settings), context ?? fakeContext())
      .take(count)
      .toList()
      .timeout(timeout);
}
