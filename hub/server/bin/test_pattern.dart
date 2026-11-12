// BuildBeacon Hub — Commissioning test pattern: sends a test pattern to WLED.
// Version 1.2 (2026-11-12) — comments in English.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:buildbeacon_core/buildbeacon_core.dart';
import 'package:buildbeacon_hub/buildbeacon_hub.dart';
import 'package:buildbeacon_hub/src/cli.dart';

String _usage(String l) => tr(
  l,
  en: '''
Test pattern: sends a test pattern to the tiles (or to the simulator) to
check the wiring and find out the chain order.

Usage: mise run test-pattern [-- options]          (at the repository root)
       dart run bin/test_pattern.dart [options]    (in hub/server)

Options:
  --host <name or IP>  WLED address (default: wled.host from --config,
                       otherwise buildbeacon.local)
  --port <n>           DDP port (default: wled.ddp_port from --config, otherwise 4048)
  --tiles <n>          project tiles chained after the master (default: from
                       --config, otherwise 2)
  --config <file>      config.json to read the address and number of tiles from
  --duration <s>       duration of each phase, in seconds (default: 5)
  --help               this help

To the simulator on this machine: mise run test-pattern -- --host 127.0.0.1
Language: BB_LANG=fr or BB_LANG=en (default: system language).''',
  fr: '''
Mire de mise en service : envoie un motif de test aux tuiles (ou au
simulateur) pour vérifier le câblage et repérer l'ordre de chaînage.

Usage : mise run test-pattern [-- options]          (à la racine du dépôt)
        dart run bin/test_pattern.dart [options]    (dans hub/server)

Options :
  --host <nom ou IP>  adresse de WLED (défaut : wled.host de --config,
                      sinon buildbeacon.local)
  --port <n>          port DDP (défaut : wled.ddp_port de --config, sinon 4048)
  --tiles <n>         tuiles projet chaînées après la master (défaut : selon
                      --config, sinon 2)
  --config <fichier>  config.json dont lire l'adresse et le nombre de tuiles
  --duration <s>      durée de chaque phase, en secondes (défaut : 5)
  --help              cette aide

Vers le simulateur sur cette machine : mise run test-pattern -- --host 127.0.0.1
Langue : BB_LANG=fr ou BB_LANG=en (défaut : langue du système).''',
);

Future<void> main(List<String> args) async {
  final l = cliLanguage();
  final usage = _usage(l);
  final options = parseOptions(
    args,
    usage: usage,
    language: l,
    withValue: {'host', 'port', 'tiles', 'config', 'duration'},
  );

  Config? config;
  if (options['config'] case final path?) {
    try {
      config = await readConfigFile(path);
    } on LocalizedFormatException catch (e) {
      fail(e.text.resolve(l));
    }
  }
  final host = options['host'] ?? config?.wled.host ?? 'buildbeacon.local';
  final port = intOption(
    options,
    'port',
    config?.wled.ddpPort ?? ddpDefaultPort,
    usage: usage,
    language: l,
  );
  final tiles = intOption(
    options,
    'tiles',
    config == null
        ? 2
        : (config.ledCount - LedLayout.masterLeds) ~/ LedLayout.projectLeds,
    usage: usage,
    language: l,
  );
  final seconds = intOption(options, 'duration', 5, usage: usage, language: l);
  if (tiles < 0 || seconds < 1) {
    fail(
      tr(
        l,
        en: '--tiles ≥ 0 and --duration ≥ 1 expected.',
        fr: '--tiles ≥ 0 et --duration ≥ 1 attendus.',
      ),
    );
  }

  final sender = await DdpSender.open(
    host: host,
    port: port,
    log: (message) => stdout.writeln(message.resolve(l)),
  );
  final address = sender.address;
  if (address == null) {
    await sender.close();
    fail(
      tr(
        l,
        en: 'Cannot find "$host". Give the IP address of WLED with --host.',
        fr:
            "Impossible de trouver « $host ». Indiquer l'adresse IP de WLED "
            'avec --host.',
      ),
    );
  }

  final pattern = TestPattern(
    projectTiles: tiles,
    phaseDuration: Duration(seconds: seconds),
  );
  final watch = Stopwatch()..start();
  final loop = LedOutputLoop(
    frameAt: pattern.frameAt,
    sink: sender,
    elapsed: () => watch.elapsed,
    log: (message) => stderr.writeln(message.resolve(l)),
  );

  final leds = pattern.ledCount;
  stdout.writeln(
    tr(
      l,
      en:
          'Test pattern sent to $host (${address.address}:$port): master + '
          '$tiles tile(s), $leds LEDs. Ctrl-C to stop.\n'
          'In WLED, the chain length (LED Preferences → Length) must be $leds.',
      fr:
          'Mire envoyée à $host (${address.address}:$port) : master + '
          '$tiles tuile(s), $leds LED. Ctrl-C pour arrêter.\n'
          'Dans WLED, la longueur de la chaîne (LED Preferences → Length) '
          'doit valoir $leds.',
    ),
  );
  TestPatternPhase? shown;
  void announce() {
    final phase = pattern.phaseAt(watch.elapsed);
    if (phase == shown) return;
    shown = phase;
    stdout.writeln('\n${phase.index + 1}/3 — ${phase.description.resolve(l)}');
  }

  announce();
  loop.start();
  final phases = Timer.periodic(
    const Duration(milliseconds: 100),
    (_) => announce(),
  );

  await ProcessSignal.sigint.watch().first;
  phases.cancel();
  loop.stop();
  sender.send(Uint8List(leds * 3)); // turn everything off right away
  await sender.close();
  final sent = loop.framesSent;
  stdout.writeln(
    tr(
      l,
      en: '\nTest pattern stopped ($sent frames sent).',
      fr: '\nMire arrêtée ($sent images envoyées).',
    ),
  );
}
