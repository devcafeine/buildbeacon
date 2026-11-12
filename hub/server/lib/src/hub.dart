// BuildBeacon Hub — The Hub: config → plugins → LED frame → WLED.
// Version 1.5 (2026-11-12) — comments in English.

import 'dart:async';
import 'dart:io';

import 'package:buildbeacon_core/buildbeacon_core.dart';
import 'package:buildbeacon_plugin_github/buildbeacon_plugin_github.dart';
import 'package:http/http.dart' as http;

import 'output/ddp_sender.dart';
import 'output/host_resolver.dart';
import 'output/led_output_loop.dart';
import 'output/wled_client.dart';
import 'source_manager.dart';

/// Frame output opened to a WLED address, and how to close it.
typedef LedOutputHandle = ({LedSink sink, Future<void> Function() close});

/// Opens the output to WLED: DDP by default ([Hub.openDdp]), replaceable in
/// tests.
typedef LedOutputOpener =
    Future<LedOutputHandle> Function(
      WledConfig wled,
      void Function(LocalizedText message) log,
    );

/// Result of the last check of WLED through its JSON API: its information,
/// or the cause of the failure.
typedef WledStatus = ({DateTime checkedAt, WledInfo? info, String? error});

/// The assembled Hub: it runs the plugins of the configuration, computes the
/// LED frame 20 times per second and sends it to WLED (or to the simulator).
///
/// [apply] switches configuration on the fly: only new sources are opened,
/// and the output is reopened only if the WLED address changes.
final class Hub {
  Hub({
    required this.plugins,
    required http.Client httpClient,
    Map<String, String> environment = const {},
    LedOutputOpener openOutput = Hub.openDdp,
    FrameRenderer renderer = const FrameRenderer(),
    HostResolver resolve = resolveIPv4,
    void Function(LocalizedText message)? log,
  }) : _http = httpClient,
       _environment = environment,
       _openOutputFor = openOutput,
       _renderer = renderer,
       _resolve = resolve,
       _log = log ?? _silent;

  final PluginRegistry plugins;
  final http.Client _http;
  final HostResolver _resolve;
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

  /// Last summary shown for each source (only changes are logged).
  final _shown = <String, String>{};

  final _events = StreamController<void>.broadcast();
  final _identifyUntil = <String, DateTime>{};
  final _clock = Stopwatch();
  WledStatus? _wled;

  Config get config => _config;

  /// Current states of the sources, by key.
  Map<String, SourceState> get states => _manager.states;

  /// Emits when what the Hub shows changes: state of a source,
  /// configuration, identified tile, WLED check.
  Stream<void> get changes => _events.stream;

  /// Last WLED check; `null` before the first one.
  WledStatus? get wled => _wled;

  /// Tiles currently blinking ("identify" button).
  Set<String> get identifying {
    final now = DateTime.now();
    _identifyUntil.removeWhere((_, until) => !until.isAfter(now));
    return _identifyUntil.keys.toSet();
  }

  /// The frame currently sent to the LEDs.
  LedFrame currentFrame() => _frameAt(_clock.elapsed);

  LedFrame _frameAt(Duration t) =>
      _renderer.render(_config, _manager.states, t, identify: identifying);

  /// Makes the tile [tileId] blink for [duration]; `false` if it does not
  /// exist in the configuration.
  bool identify(
    String tileId, {
    Duration duration = const Duration(seconds: 5),
  }) {
    if (!_config.tiles.any((tile) => tile.id == tileId)) return false;
    _identifyUntil[tileId] = DateTime.now().add(duration);
    _notify();
    Timer(duration, _notify);
    return true;
  }

  void _notify() {
    if (!_events.isClosed) _events.add(null);
  }

  /// Opens the DDP output to WLED.
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
    _changes = _manager.changes.listen((_) {
      _reportChanges();
      _notify();
    });
    await _openOutput(config.wled);
    await _manager.apply(config);
    _clock.start();
    _loop = LedOutputLoop(
      frameAt: _frameAt,
      sink: _sink,
      elapsed: () => _clock.elapsed,
      log: _log,
    )..start();
    // In the background: a WLED missing from the network takes several
    // seconds to answer (mDNS name, timeout); the result arrives through
    // [changes].
    unawaited(checkWled());
  }

  /// Switches to a new, already validated configuration.
  Future<void> apply(Config config) async {
    final previous = _config.wled;
    final wled = config.wled;
    _config = config;
    if (wled.host != previous.host || wled.ddpPort != previous.ddpPort) {
      await _closeOutput();
      await _openOutput(wled);
    }
    await _manager.apply(config);
    _identifyUntil.removeWhere(
      (id, _) => !config.tiles.any((tile) => tile.id == id),
    );
    _reportChanges();
    _notify();
    if (wled.host != previous.host ||
        wled.port != previous.port ||
        wled.brightness != previous.brightness) {
      unawaited(checkWled());
    }
  }

  /// Checks WLED through its JSON API (connection, LED count) and sets the
  /// brightness. An unreachable API does not prevent sending the colors over
  /// DDP (simulator, filtered network): it is only reported.
  Future<WledStatus> checkWled() => lastWledCheck = () async {
    final status = await _checkWled();
    _wled = status;
    _notify();
    return status;
  }();

  /// Last WLED check started (at startup, when a configuration that affects
  /// WLED is saved, or requested through the API).
  Future<WledStatus>? lastWledCheck;

  Future<WledStatus> _checkWled() async {
    final wled = _config.wled;
    final expected = _config.ledCount;
    try {
      // Same resolution as the DDP output: a .local name also resolves in a
      // Docker container, without an mDNS daemon.
      final address = await _resolve(wled.host);
      if (address == null) throw const SocketException('name not found');
      final client = WledClient(
        host: address.address,
        port: wled.port,
        client: _http,
      );
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
      return (checkedAt: DateTime.now(), info: info, error: null);
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
      return (checkedAt: DateTime.now(), info: null, error: reason);
    }
  }

  Future<void> stop() async {
    _loop?.stop();
    await _changes?.cancel();
    await _manager.close();
    await _closeOutput();
    await _events.close();
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

  /// Logs each source whose displayed state has changed.
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

/// Output that follows the current WLED connection (reopened if the address
/// changes).
final class _SwitchSink implements LedSink {
  LedSink? target;

  @override
  void send(rgb) => target?.send(rgb);
}

/// Readable name of a source: `github · owner/repo · ci.yml · main`.
String describeSource(SourceConfig source) => [
  source.type,
  for (final value in source.settings.values) '$value',
].join(' · ');

/// Summary of a state in language [l]: status, history, measurements, error.
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

/// Warning if, without a GitHub token, polling exceeds GitHub's anonymous
/// quota (60 requests per hour; without a token, even 304 responses count).
/// `null` if all is well.
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

/// Readable cause of a network error, without the socket details
/// ("Connection refused", "timeout"…).
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
