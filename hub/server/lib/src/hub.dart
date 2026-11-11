// BuildBeacon Hub — Le Hub : config → plugins → image des LED → WLED.
// Version 1.1 (2026-11-11) — cause courte d'une erreur réseau vers WLED.

import 'dart:async';

import 'package:buildbeacon_core/buildbeacon_core.dart';
import 'package:buildbeacon_plugin_github/buildbeacon_plugin_github.dart';
import 'package:http/http.dart' as http;

import 'output/ddp_sender.dart';
import 'output/led_output_loop.dart';
import 'output/wled_client.dart';
import 'source_manager.dart';

/// Sortie des images ouverte vers une adresse WLED, et sa fermeture.
typedef LedOutputHandle = ({LedSink sink, Future<void> Function() close});

/// Ouvre la sortie vers WLED : DDP par défaut ([Hub.openDdp]), remplaçable
/// dans les tests.
typedef LedOutputOpener =
    Future<LedOutputHandle> Function(
      WledConfig wled,
      void Function(LocalizedText message) log,
    );

/// Le Hub assemblé : il fait tourner les plugins de la configuration, calcule
/// l'image des LED 20 fois par seconde et l'envoie à WLED (ou au simulateur).
///
/// [apply] change de configuration à chaud : seules les sources nouvelles
/// sont ouvertes, la sortie n'est rouverte que si l'adresse de WLED change.
final class Hub {
  Hub({
    required this.plugins,
    required http.Client httpClient,
    Map<String, String> environment = const {},
    LedOutputOpener openOutput = Hub.openDdp,
    FrameRenderer renderer = const FrameRenderer(),
    void Function(LocalizedText message)? log,
  }) : _http = httpClient,
       _environment = environment,
       _openOutputFor = openOutput,
       _renderer = renderer,
       _log = log ?? _silent;

  final PluginRegistry plugins;
  final http.Client _http;
  final Map<String, String> _environment;
  final LedOutputOpener _openOutputFor;
  final FrameRenderer _renderer;
  final void Function(LocalizedText message) _log;

  late Config _config;
  late final SourceManager _manager;
  StreamSubscription<void>? _changes;
  LedOutputLoop? _loop;
  LedOutputHandle? _output;
  final _sink = _SwitchSink();

  /// Dernier résumé affiché pour chaque source (seuls les changements sont
  /// journalisés).
  final _shown = <String, String>{};

  Config get config => _config;

  /// États actuels des sources, par clé.
  Map<String, SourceState> get states => _manager.states;

  /// Ouvre la sortie DDP vers WLED.
  static Future<LedOutputHandle> openDdp(
    WledConfig wled,
    void Function(LocalizedText message) log,
  ) async {
    final sender = await DdpSender.open(
      host: wled.host,
      port: wled.ddpPort,
      log: log,
    );
    return (sink: sender, close: sender.close);
  }

  Future<void> start(Config config) async {
    _config = config;
    _manager = SourceManager(
      plugins: plugins,
      httpClient: _http,
      environment: _environment,
      log: (message) => _log(LocalizedText.same(message)),
    );
    _changes = _manager.changes.listen((_) => _reportChanges());
    await _openOutput(config.wled);
    await _manager.apply(config);
    _loop = LedOutputLoop(
      frameAt: (t) => _renderer.render(_config, _manager.states, t),
      sink: _sink,
      log: _log,
    )..start();
    await checkWled();
  }

  /// Passe à une nouvelle configuration, déjà validée.
  Future<void> apply(Config config) async {
    final previous = _config.wled;
    final wled = config.wled;
    _config = config;
    if (wled.host != previous.host || wled.ddpPort != previous.ddpPort) {
      await _closeOutput();
      await _openOutput(wled);
    }
    await _manager.apply(config);
    _reportChanges();
    if (wled.host != previous.host ||
        wled.port != previous.port ||
        wled.brightness != previous.brightness) {
      await checkWled();
    }
  }

  /// Vérifie WLED par son API JSON (connexion, nombre de LED) et règle la
  /// luminosité. Une API injoignable n'empêche pas l'envoi des couleurs en
  /// DDP (simulateur, réseau filtré) : elle est seulement signalée.
  Future<void> checkWled() async {
    final wled = _config.wled;
    final expected = _config.ledCount;
    final client = WledClient(host: wled.host, port: wled.port, client: _http);
    try {
      final info = await client.info();
      _log(
        LocalizedText.build(
          (l) => tr(
            l,
            en: 'WLED ${info.version} "${info.name}": ${info.ledCount} LEDs',
            fr: 'WLED ${info.version} « ${info.name} » : ${info.ledCount} LED',
          ),
        ),
      );
      if (info.ledCount != expected) {
        _log(
          LocalizedText.build(
            (l) => tr(
              l,
              en:
                  'WLED is set to ${info.ledCount} LEDs but the configuration '
                  'describes $expected: adjust LED Preferences → Length in WLED',
              fr:
                  'WLED est réglé sur ${info.ledCount} LED mais la '
                  'configuration en décrit $expected : ajuster LED Preferences '
                  '→ Length dans WLED',
            ),
          ),
        );
      }
      await client.setBrightness(wled.brightness);
      _log(
        LocalizedText.build(
          (l) => tr(
            l,
            en: 'WLED brightness: ${wled.brightness}/255',
            fr: 'Luminosité WLED : ${wled.brightness}/255',
          ),
        ),
      );
    } catch (error) {
      final url = 'http://${wled.host}:${wled.port}';
      final reason = _shortError(error);
      _log(
        LocalizedText.build(
          (l) => tr(
            l,
            en:
                'WLED JSON API unreachable at $url ($reason): the colors are '
                'still sent over DDP (normal with the simulator)',
            fr:
                'API JSON de WLED injoignable sur $url ($reason) : les '
                'couleurs partent quand même en DDP (normal avec le '
                'simulateur)',
          ),
        ),
      );
    }
  }

  Future<void> stop() async {
    _loop?.stop();
    await _changes?.cancel();
    await _manager.close();
    await _closeOutput();
  }

  Future<void> _openOutput(WledConfig wled) async {
    final output = await _openOutputFor(wled, _log);
    _output = output;
    _sink.target = output.sink;
  }

  Future<void> _closeOutput() async {
    final output = _output;
    _output = null;
    _sink.target = null;
    await output?.close();
  }

  /// Journalise chaque source dont l'état affiché a changé.
  void _reportChanges() {
    final states = _manager.states;
    _shown.removeWhere((key, _) => !states.containsKey(key));
    for (final MapEntry(key: key, value: state) in states.entries) {
      final summary = describeState(state, fallbackLanguage);
      if (_shown[key] == summary) continue;
      _shown[key] = summary;
      final source = _sourceFor(key);
      final label = source == null ? key : describeSource(source);
      _log(LocalizedText.build((l) => '$label — ${describeState(state, l)}'));
    }
  }

  SourceConfig? _sourceFor(String key) {
    for (final tile in _config.tiles) {
      for (final action in tile.zones.values) {
        if (action.source.key == key) return action.source;
      }
    }
    return null;
  }

  static void _silent(LocalizedText message) {}
}

/// Sortie qui suit la connexion WLED du moment (rouverte si l'adresse change).
final class _SwitchSink implements LedSink {
  LedSink? target;

  @override
  void send(rgb) => target?.send(rgb);
}

/// Nom lisible d'une source : `github · owner/repo · ci.yml · main`.
String describeSource(SourceConfig source) => [
  source.type,
  for (final value in source.settings.values) '$value',
].join(' · ');

/// Résumé d'un état dans la langue [l] : état, historique, mesures, erreur.
String describeState(SourceState state, String l) {
  String number(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
  return [
    state.status.label.resolve(l),
    if (state.history.length > 1)
      '${tr(l, en: 'history', fr: 'historique')} '
          '${state.history.map((s) => s.label.resolve(l)).join(', ')}',
    for (final MapEntry(key: id, value: metric) in state.metrics.entries)
      '$id ${number(metric.value)}${metric.unit == null ? '' : ' ${metric.unit}'}',
    if (state.error case final error?) '⚠ ${error.resolve(l)}',
  ].join(' · ');
}

/// Avertissement si, sans jeton GitHub, la scrutation dépasse le quota
/// anonyme de GitHub (60 requêtes par heure ; sans jeton, même les réponses
/// 304 comptent). `null` si tout va bien.
LocalizedText? githubQuotaWarning(
  Config config,
  Map<String, String> environment,
) {
  if ((environment[GithubPlugin.tokenEnv] ?? '').isNotEmpty) return null;
  final sources = {
    for (final tile in config.tiles)
      for (final action in tile.zones.values)
        if (action.source.type == 'github') action.source.key,
  }.length;
  if (sources == 0) return null;
  final perHour = (sources * 3600 / config.pollSeconds).ceil();
  if (perHour <= 60) return null;
  final minimum = sources * 60;
  final poll = config.pollSeconds;
  return LocalizedText.build(
    (l) => tr(
      l,
      en:
          'Without BB_GITHUB_TOKEN, GitHub allows 60 requests per hour: '
          '$sources GitHub sources every $poll s need $perHour. Set '
          'poll_seconds to at least $minimum, or add a token.',
      fr:
          'Sans BB_GITHUB_TOKEN, GitHub autorise 60 requêtes par heure : '
          '$sources sources GitHub toutes les $poll s en demandent $perHour. '
          'Régler poll_seconds à $minimum au moins, ou ajouter un jeton.',
    ),
  );
}

/// Cause lisible d'une erreur réseau, sans les détails de socket
/// (« Connection refused », « timeout »…).
String _shortError(Object error) {
  if (error is TimeoutException) return 'timeout';
  final text = error is http.ClientException ? error.message : '$error';
  return text
      .split(' (OS Error')
      .first
      .split(', address')
      .first
      .replaceFirst('SocketException: ', '');
}
