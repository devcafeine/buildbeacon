// BuildBeacon Hub — WLED simulator: web page (default) or terminal.
// Version 1.4 (2026-11-12) — follows config.json live (layout and tile names).

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:buildbeacon_core/buildbeacon_core.dart';
import 'package:buildbeacon_hub/buildbeacon_hub.dart';
import 'package:buildbeacon_hub/src/cli.dart';

String _usage(String l) => tr(
  l,
  en: '''
WLED simulator: receives the DDP frames of the Hub (or of the test pattern)
and shows the tiles without the hardware, in a web page by default or in the
terminal.

Usage: mise run simulator [-- options]          (at the repository root)
       dart run bin/simulator.dart [options]    (in hub/server)

Options:
  --port <n>          UDP port for DDP (default: 4048, like WLED)
  --config <file>     config.json: real layout and tile names, followed live
  --http <n>          web page port (default: 8090)
  --network           page reachable from other machines (default: this one only)
  --open              open the page in the browser
  --terminal          draw in the terminal instead of the web page
  --raw               (terminal) raw colors, no screen correction
  --help              this help

Language: BB_LANG=fr or BB_LANG=en (default: system language).''',
  fr: '''
Simulateur WLED : reçoit les images DDP du Hub (ou de la mire) et montre les
tuiles sans le matériel, dans une page web par défaut ou dans le terminal.

Usage : mise run simulator [-- options]          (à la racine du dépôt)
        dart run bin/simulator.dart [options]    (dans hub/server)

Options :
  --port <n>          port UDP d'écoute DDP (défaut : 4048, comme WLED)
  --config <fichier>  config.json : vraie disposition et noms des tuiles, suivis en direct
  --http <n>          port de la page web (défaut : 8090)
  --network           page visible depuis les autres machines (défaut : celle-ci seulement)
  --open              ouvre la page dans le navigateur
  --terminal          dessine dans le terminal au lieu de la page web
  --raw               (terminal) couleurs brutes, sans correction pour l'écran
  --help              cette aide

Langue : BB_LANG=fr ou BB_LANG=en (défaut : langue du système).''',
);

Future<void> main(List<String> args) async {
  final l = cliLanguage();
  final usage = _usage(l);
  final options = parseOptions(
    args,
    usage: usage,
    language: l,
    withValue: {'port', 'config', 'http'},
    flags: {'raw', 'terminal', 'network', 'open'},
  );
  final port = intOption(
    options,
    'port',
    ddpDefaultPort,
    usage: usage,
    language: l,
  );
  final httpPort = intOption(options, 'http', 8090, usage: usage, language: l);

  // config.json is followed: tiles added, moved or renamed (web interface,
  // editor) show up without restarting the simulator.
  final configPath = options['config'];

  final DdpReceiver receiver;
  try {
    receiver = await DdpReceiver.bind(port: port);
  } on SocketException catch (e) {
    final reason = e.osError?.message ?? e.message;
    fail(
      tr(
        l,
        en:
            'UDP port $port unavailable ($reason). '
            'Is another simulator already running?',
        fr:
            'Port UDP $port indisponible ($reason). '
            'Un autre simulateur tourne-t-il déjà ?',
      ),
    );
  }
  final addresses = await _localAddresses();

  if (options.containsKey('terminal')) {
    await _runTerminal(
      receiver,
      l,
      port: port,
      configPath: configPath,
      addresses: addresses,
      raw: options.containsKey('raw'),
    );
  } else {
    await _runWeb(
      receiver,
      l,
      port: port,
      httpPort: httpPort,
      configPath: configPath,
      addresses: addresses,
      network: options.containsKey('network'),
      open: options.containsKey('open'),
    );
  }
}

/// Addresses to give to the Hub, presented in language [l].
String _hosts(List<String> addresses, String l) {
  final [loopback, ...others] = addresses;
  return [
    '$loopback (${tr(l, en: 'same machine', fr: 'même machine')})',
    ...others,
  ].join(tr(l, en: ' or ', fr: ' ou '));
}

// ---------------------------------------------------------------------------
// Web page

Future<void> _runWeb(
  DdpReceiver receiver,
  String l, {
  required int port,
  required int httpPort,
  required String? configPath,
  required List<String> addresses,
  required bool network,
  required bool open,
}) async {
  final WebSimulator web;
  try {
    web = await WebSimulator.start(
      frames: receiver.frames,
      layout: simulatorLayout(ddpPort: port, addresses: addresses),
      port: httpPort,
      address: network ? InternetAddress.anyIPv4 : null,
    );
  } on SocketException catch (e) {
    await receiver.close();
    final reason = e.osError?.message ?? e.message;
    fail(
      tr(
        l,
        en:
            'HTTP port $httpPort unavailable ($reason). '
            'Choose another one with --http.',
        fr:
            'Port HTTP $httpPort indisponible ($reason). '
            'En choisir un autre avec --http.',
      ),
    );
  }

  final url = 'http://localhost:${web.port}';
  final fromNetwork = network
      ? tr(
          l,
          en: ' (from the network: http://<IP of this machine>:${web.port})',
          fr: ' (depuis le réseau : http://<IP de cette machine>:${web.port})',
        )
      : '';
  stdout.writeln(
    tr(
      l,
      en:
          'WLED simulator — DDP on UDP $port\n'
          'Page: $url$fromNetwork\n'
          'Hub or test pattern side: wled.host = ${_hosts(addresses, l)}, '
          'wled.ddp_port = $port.\n'
          'Ctrl-C to quit.',
      fr:
          'Simulateur WLED — DDP sur UDP $port\n'
          'Page : $url$fromNetwork\n'
          'Côté Hub ou mire : wled.host = ${_hosts(addresses, l)}, '
          'wled.ddp_port = $port.\n'
          'Ctrl-C pour quitter.',
    ),
  );
  if (configPath != null) {
    followConfigFile(
      configPath,
      log: (message) => stdout.writeln(message.resolve(l)),
    ).listen(
      (config) => web.updateLayout(
        simulatorLayout(config: config, ddpPort: port, addresses: addresses),
      ),
    );
  }
  if (open) await _openBrowser(url, l);

  // Minimal log: start and end of a frame stream.
  String? sender;
  DateTime? lastAt;
  receiver.frames.listen((frame) {
    if (frame.from.address != sender) {
      sender = frame.from.address;
      final count = frame.rgb.length ~/ 3;
      stdout.writeln(
        tr(
          l,
          en: 'Frames received from $sender ($count LEDs).',
          fr: 'Images reçues de $sender ($count LED).',
        ),
      );
    }
    lastAt = DateTime.now();
  });
  final watchdog = Timer.periodic(const Duration(milliseconds: 500), (_) {
    final at = lastAt;
    if (at == null) return;
    final age = DateTime.now().difference(at);
    if (age <= wledRealtimeTimeout) return;
    stdout.writeln(_staleMessage(age, l));
    lastAt = null;
    sender = null;
  });

  await ProcessSignal.sigint.watch().first;
  watchdog.cancel();
  await web.close();
  await receiver.close();
  exit(0);
}

String _staleMessage(Duration age, String l) {
  final seconds = formatSeconds(age, l);
  return tr(
    l,
    en:
        'No frame for $seconds: a real WLED would have gone back to its '
        'own effect.',
    fr:
        "Plus d'image depuis $seconds : un vrai WLED aurait repris son "
        'propre affichage.',
  );
}

Future<void> _openBrowser(String url, String l) async {
  final command = Platform.isMacOS
      ? 'open'
      : Platform.isWindows
      ? 'explorer'
      : 'xdg-open';
  try {
    await Process.run(command, [url]);
  } on ProcessException {
    stdout.writeln(
      tr(
        l,
        en: 'Open $url in a browser.',
        fr: 'Ouvrir $url dans un navigateur.',
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Terminal

Future<void> _runTerminal(
  DdpReceiver receiver,
  String l, {
  required int port,
  required String? configPath,
  required List<String> addresses,
  required bool raw,
}) async {
  // Tile names by chain position, following config.json.
  var labels = <int, String>{};
  final terminal = stdout.hasTerminal;
  var dirty = true;
  if (configPath != null) {
    followConfigFile(
      configPath,
      // Full-screen drawing: no log line in the middle of it.
      log: terminal ? null : (message) => stdout.writeln(message.resolve(l)),
    ).listen((config) {
      labels = {
        for (final tile in config?.tiles ?? const <Tile>[])
          tile.chainIndex: tile.label.isEmpty ? tile.id : tile.label,
      };
      dirty = true;
    });
  }
  ReceivedFrame? last;
  DateTime? lastAt;
  final arrivals = <DateTime>[];

  receiver.frames.listen((frame) {
    final now = DateTime.now();
    last = frame;
    lastAt = now;
    arrivals.add(now);
    dirty = true;
  });

  String status() {
    final now = DateTime.now();
    arrivals.removeWhere((a) => now.difference(a) > const Duration(seconds: 1));
    final (frame, at) = (last, lastAt);
    if (frame == null || at == null) {
      return tr(
        l,
        en:
            'Waiting for DDP frames on port $port.\n'
            'Hub or test pattern side: wled.host = ${_hosts(addresses, l)}, '
            'wled.ddp_port = $port.',
        fr:
            "En attente d'images DDP sur le port $port.\n"
            'Côté Hub ou mire : wled.host = ${_hosts(addresses, l)}, '
            'wled.ddp_port = $port.',
      );
    }
    final age = now.difference(at);
    final count = frame.rgb.length ~/ 3;
    final seconds = formatSeconds(age, l);
    final line = tr(
      l,
      en:
          '$count LEDs · ${arrivals.length} fps · last frame $seconds ago · '
          'sender ${frame.from.address}',
      fr:
          '$count LED · ${arrivals.length} img/s · dernière image il y a '
          '$seconds · émetteur ${frame.from.address}',
    );
    if (age <= wledRealtimeTimeout) return line;
    return '$line\n${_staleMessage(age, l)}';
  }

  final header = tr(
    l,
    en: 'WLED simulator — DDP on UDP $port (Ctrl-C to quit)',
    fr: 'Simulateur WLED — DDP sur UDP $port (Ctrl-C pour quitter)',
  );
  if (terminal) {
    stdout.write('\x1b[?25l\x1b[2J'); // hide the cursor, clear the screen
    var shownStatus = '';
    Timer.periodic(const Duration(milliseconds: 50), (_) {
      final text = status();
      if (!dirty && text == shownStatus) return;
      dirty = false;
      shownStatus = text;
      final frame = last;
      final panel = frame == null
          ? ''
          : renderTerminalPanel(
              frame.rgb,
              labels: labels,
              columns: stdout.terminalColumns,
              raw: raw,
              language: l,
            );
      final screen = '$header\n\n$panel\n\n$text'.replaceAll('\n', '\x1b[K\n');
      stdout.write('\x1b[H$screen\x1b[K\x1b[J');
    });
  } else {
    // Redirected output (log, test): one line per second if anything changed.
    stdout
      ..writeln(header)
      ..writeln(status());
    Timer.periodic(const Duration(seconds: 1), (_) {
      final frame = last;
      if (!dirty || frame == null) return;
      dirty = false;
      stdout.writeln('${status()}\n  ${_hexLine(frame.rgb)}');
    });
  }

  await ProcessSignal.sigint.watch().first;
  if (terminal) stdout.write('\x1b[?25h\n');
  await receiver.close();
  exit(0);
}

/// IPv4 addresses of this machine, to give to the Hub; loopback first.
Future<List<String>> _localAddresses() async {
  final interfaces = await NetworkInterface.list(
    type: InternetAddressType.IPv4,
  );
  return [
    '127.0.0.1',
    for (final interface in interfaces)
      for (final address in interface.addresses)
        if (!address.isLoopback) address.address,
  ];
}

/// Colors in hexadecimal, tile by tile (master | no. 1 | no. 2 …).
String _hexLine(Uint8List rgb) {
  final hex = [
    for (var i = 0; i + 2 < rgb.length; i += 3)
      Rgb(rgb[i], rgb[i + 1], rgb[i + 2]).toHex(),
  ];
  final groups = [
    hex.take(LedLayout.masterLeds).join(' '),
    for (
      var start = LedLayout.masterLeds;
      start < hex.length;
      start += LedLayout.projectLeds
    )
      hex.skip(start).take(LedLayout.projectLeds).join(' '),
  ];
  return groups.join(' | ');
}
