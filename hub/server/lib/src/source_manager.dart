// BuildBeacon Hub — Plugin execution and cache of the source states.
// Version 1.3 (2026-11-12) — comments in English.

import 'dart:async';

import 'package:buildbeacon_core/buildbeacon_core.dart';
import 'package:http/http.dart' as http;

/// Runs the plugins: one connection per distinct source of the
/// configuration (two zones that follow the same repository share it), and
/// the latest state of each in [states], ready for rendering.
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

  /// Technical log (in English).
  final void Function(String message) _log;

  final _states = <String, SourceState>{};
  final _subscriptions = <String, StreamSubscription<SourceState>>{};

  /// Sources that could not be opened (missing plugin, invalid settings):
  /// their state carries the error; retried on the next interval change or
  /// if they disappear and come back.
  final _failed = <String>{};
  final _changes = StreamController<void>.broadcast();
  int? _pollSeconds;

  /// Latest state of each source, by source key.
  Map<String, SourceState> get states => Map.unmodifiable(_states);

  /// Emits on every new state of a source: the signal to recompute the frame
  /// and notify the interface.
  Stream<void> get changes => _changes.stream;

  /// Aligns the connections with [config]: opens the new sources, closes the
  /// ones no longer used. A change of the polling interval reopens all the
  /// sources, keeping the last displayed states.
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

  /// Closes all the connections.
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
