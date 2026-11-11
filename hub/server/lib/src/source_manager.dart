// BuildBeacon Hub — Exécution des plugins et cache de l'état des sources.
// Version 1.2 (2026-11-11) — erreurs des sources traduites.

import 'dart:async';

import 'package:buildbeacon_core/buildbeacon_core.dart';
import 'package:http/http.dart' as http;

/// Fait tourner les plugins : une connexion par source distincte de la
/// configuration (deux zones qui suivent le même dépôt partagent la même),
/// et le dernier état de chacune dans [states], prêt pour le rendu.
final class SourceManager {
  SourceManager({
    required this.plugins,
    required http.Client httpClient,
    Map<String, String> environment = const {},
    void Function(String message)? log,
  }) : _http = httpClient,
       _environment = environment,
       _log = log ?? _silent;

  final PluginRegistry plugins;
  final http.Client _http;
  final Map<String, String> _environment;

  /// Journal technique (en anglais).
  final void Function(String message) _log;

  final _states = <String, SourceState>{};
  final _subscriptions = <String, StreamSubscription<SourceState>>{};

  /// Sources qui n'ont pas pu s'ouvrir (plugin absent, réglages invalides) :
  /// leur état porte l'erreur ; nouvel essai au prochain changement
  /// d'intervalle ou si elles disparaissent puis reviennent.
  final _failed = <String>{};
  final _changes = StreamController<void>.broadcast();
  int? _pollSeconds;

  /// Dernier état de chaque source, par clé de source.
  Map<String, SourceState> get states => Map.unmodifiable(_states);

  /// Émet à chaque nouvel état d'une source : signal pour recalculer
  /// l'image et prévenir l'interface.
  Stream<void> get changes => _changes.stream;

  /// Aligne les connexions sur [config] : ouvre les sources nouvelles, ferme
  /// celles qui ne servent plus. Un changement d'intervalle de scrutation
  /// rouvre toutes les sources, en gardant les derniers états affichés.
  Future<void> apply(Config config) async {
    if (_pollSeconds != config.pollSeconds) {
      await _cancelAll();
      _pollSeconds = config.pollSeconds;
    }

    final wanted = {
      for (final tile in config.tiles)
        for (final action in tile.zones.values)
          action.source.key: action.source,
    };

    for (final key in _subscriptions.keys.toList()) {
      if (!wanted.containsKey(key)) await _subscriptions.remove(key)!.cancel();
    }
    _failed.removeWhere((key) => !wanted.containsKey(key));
    _states.removeWhere((key, _) => !wanted.containsKey(key));

    final interval = Duration(seconds: config.pollSeconds);
    for (final MapEntry(:key, value: source) in wanted.entries) {
      if (!_subscriptions.containsKey(key) && !_failed.contains(key)) {
        _open(key, source, interval);
      }
    }
  }

  /// Ferme toutes les connexions.
  Future<void> close() async {
    await _cancelAll();
    _states.clear();
    await _changes.close();
  }

  void _open(String key, SourceConfig source, Duration interval) {
    final plugin = plugins[source.type];
    if (plugin == null) {
      _fail(
        key,
        LocalizedText.build(
          (l) => tr(
            l,
            en: 'no "${source.type}" plugin',
            fr: 'aucun plugin « ${source.type} »',
          ),
        ),
      );
      return;
    }

    final issues = [
      ...plugins.validateSource(source),
      for (final secret in plugin.secrets)
        if (secret.required && _environment[secret.env] == null)
          LocalizedText.build(
            (l) => tr(
              l,
              en: 'environment variable ${secret.env} is missing',
              fr: 'variable d\'environnement ${secret.env} absente',
            ),
          ),
    ];
    if (issues.isNotEmpty) {
      _fail(key, LocalizedText.build((l) => issues.resolveAll(l).join(' ; ')));
      return;
    }

    final context = PluginContext(
      httpClient: _http,
      pollInterval: interval,
      secrets: {
        for (final secret in plugin.secrets)
          secret.env: ?_environment[secret.env],
      },
      log: (message) => _log('[${plugin.type}] $message'),
    );
    try {
      _subscriptions[key] = plugin
          .connect(SourceSettings(source.settings), context)
          .listen(
            (state) => _update(key, state),
            onError: (Object error) => _update(
              key,
              (_states[key] ?? SourceState.unknown).withError(
                LocalizedText.same('$error'),
              ),
            ),
          );
    } catch (error) {
      _fail(
        key,
        LocalizedText.build(
          (l) => tr(
            l,
            en: '${plugin.label.resolve(l)} could not start: $error',
            fr: '${plugin.label.resolve(l)} n\'a pas pu démarrer : $error',
          ),
        ),
      );
    }
  }

  void _fail(String key, LocalizedText error) {
    _failed.add(key);
    _update(key, (_states[key] ?? SourceState.unknown).withError(error));
  }

  void _update(String key, SourceState state) {
    _states[key] = state;
    if (!_changes.isClosed) _changes.add(null);
  }

  Future<void> _cancelAll() async {
    await Future.wait([for (final s in _subscriptions.values) s.cancel()]);
    _subscriptions.clear();
    _failed.clear();
  }

  static void _silent(String message) {}
}
