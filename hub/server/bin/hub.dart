// BuildBeacon Hub — Programme principal : config.json → plugins → image des LED → WLED.
// Version 1.0 (2026-11-11)

import 'dart:async';
import 'dart:io';

import 'package:buildbeacon_core/buildbeacon_core.dart';
import 'package:buildbeacon_hub/buildbeacon_hub.dart';
import 'package:buildbeacon_hub/src/cli.dart';
import 'package:buildbeacon_plugin_github/buildbeacon_plugin_github.dart';
import 'package:http/http.dart' as http;

String _usage(String l) => tr(
  l,
  en: '''
BuildBeacon Hub: reads config.json, runs the source plugins and sends the LED
frames to WLED (or to the simulator). Reloads config.json when it changes.

Usage: mise run hub [-- options]          (at the repository root: uses
                                          data/config.json and .env)
       dart run bin/hub.dart [options]    (in hub/server)

Options:
  --config <file>     configuration (default: BB_CONFIG, otherwise /data/config.json)
  --env-file <file>   variables file such as .env (optional; real environment
                      variables take precedence)
  --help              this help

Secret: BB_GITHUB_TOKEN (optional for public repositories, 60 requests per hour
without it). Language: BB_LANG=fr or BB_LANG=en (default: system language).''',
  fr: '''
BuildBeacon Hub : lit config.json, fait tourner les plugins de source et envoie
les images des LED à WLED (ou au simulateur). Recharge config.json quand il
change.

Usage : mise run hub [-- options]          (à la racine du dépôt : utilise
                                           data/config.json et .env)
        dart run bin/hub.dart [options]    (dans hub/server)

Options :
  --config <fichier>    configuration (défaut : BB_CONFIG, sinon /data/config.json)
  --env-file <fichier>  fichier de variables comme .env (facultatif ; les vraies
                        variables d'environnement ont priorité)
  --help                cette aide

Secret : BB_GITHUB_TOKEN (facultatif pour les dépôts publics, 60 requêtes par
heure sans lui). Langue : BB_LANG=fr ou BB_LANG=en (défaut : langue du système).''',
);

Future<void> main(List<String> args) async {
  final systemLanguage = cliLanguage();
  final options = parseOptions(
    args,
    usage: _usage(systemLanguage),
    language: systemLanguage,
    withValue: {'config', 'env-file'},
  );
  final environment = await loadEnvironment(envFile: options['env-file']);
  // BB_LANG peut venir du fichier .env.
  final l = environment['BB_LANG'] == null
      ? systemLanguage
      : languageOf(environment['BB_LANG']);
  void log(LocalizedText message) =>
      stdout.writeln('${_time()} ${message.resolve(l)}');

  final configPath =
      options['config'] ?? environment['BB_CONFIG'] ?? '/data/config.json';
  final plugins = builtinPlugins();
  final Config config;
  try {
    config = await readConfigFile(configPath);
  } on LocalizedFormatException catch (e) {
    fail(
      '${e.text.resolve(l)}\n'
      '${tr(l, en: 'To start: copy config.example.json to $configPath.', fr: 'Pour commencer : copier config.example.json vers $configPath.')}',
    );
  }
  final issues = config.validate(plugins: plugins);
  if (issues.isNotEmpty) {
    fail(
      '${tr(l, en: 'The configuration $configPath has problems:', fr: 'La configuration $configPath a des problèmes :')}\n'
      '${issues.resolveAll(l).map((issue) => '  - $issue').join('\n')}',
    );
  }

  final wled = config.wled;
  final tiles = config.tiles.length;
  final leds = config.ledCount;
  final poll = config.pollSeconds;
  log(
    LocalizedText.build(
      (l) => tr(
        l,
        en:
            'BuildBeacon Hub — $configPath: $tiles tiles, $leds LEDs, WLED '
            '${wled.host} (DDP port ${wled.ddpPort}), polling every $poll s',
        fr:
            'BuildBeacon Hub — $configPath : $tiles tuiles, $leds LED, WLED '
            '${wled.host} (port DDP ${wled.ddpPort}), scrutation toutes les '
            '$poll s',
      ),
    ),
  );
  log(
    environment.containsKey(GithubPlugin.tokenEnv)
        ? const LocalizedText({
            'en': 'GitHub: token found (BB_GITHUB_TOKEN)',
            'fr': 'GitHub : jeton trouvé (BB_GITHUB_TOKEN)',
          })
        : const LocalizedText({
            'en': 'GitHub: no token, public repositories only',
            'fr': 'GitHub : pas de jeton, dépôts publics seulement',
          }),
  );
  if (githubQuotaWarning(config, environment) case final warning?) {
    log(warning);
  }

  final httpClient = http.Client();
  final hub = Hub(
    plugins: plugins,
    httpClient: httpClient,
    environment: environment,
    log: log,
  );
  await hub.start(config);

  // Rechargement à chaud : surveiller le dossier, car beaucoup d'éditeurs
  // remplacent le fichier au lieu de le réécrire.
  final file = File(configPath).absolute;
  final name = _fileName(file.path);
  Timer? debounce;
  Future<void> reload() async {
    try {
      final next = await readConfigFile(configPath);
      final problems = next.validate(plugins: plugins);
      if (problems.isNotEmpty) {
        log(
          LocalizedText.build(
            (l) => tr(
              l,
              en: 'New configuration refused, the previous one is kept:',
              fr: 'Nouvelle configuration refusée, la précédente est gardée :',
            ),
          ),
        );
        for (final problem in problems) {
          log(LocalizedText.build((l) => '  - ${problem.resolve(l)}'));
        }
        return;
      }
      await hub.apply(next);
      log(
        const LocalizedText({
          'en': 'Configuration reloaded',
          'fr': 'Configuration rechargée',
        }),
      );
      if (githubQuotaWarning(next, environment) case final warning?) {
        log(warning);
      }
    } on LocalizedFormatException catch (e) {
      log(
        LocalizedText.build(
          (l) => tr(
            l,
            en: '${e.text.resolve(l)} — the previous configuration is kept',
            fr: '${e.text.resolve(l)} — la configuration précédente est gardée',
          ),
        ),
      );
    }
  }

  final watcher = file.parent
      .watch()
      .where(
        (event) =>
            _fileName(event.path) == name ||
            (event is FileSystemMoveEvent &&
                _fileName(event.destination ?? '') == name),
      )
      .listen((_) {
        debounce?.cancel();
        debounce = Timer(
          const Duration(milliseconds: 300),
          () => unawaited(reload()),
        );
      });

  // Arrêt propre : Ctrl-C, ou SIGTERM envoyé par Docker.
  final stop = Completer<void>();
  void requestStop(ProcessSignal _) {
    if (!stop.isCompleted) stop.complete();
  }

  ProcessSignal.sigint.watch().listen(requestStop);
  if (!Platform.isWindows) ProcessSignal.sigterm.watch().listen(requestStop);
  await stop.future;

  log(const LocalizedText({'en': 'Stopping…', 'fr': 'Arrêt…'}));
  debounce?.cancel();
  await watcher.cancel();
  await hub.stop();
  httpClient.close();
  exit(0);
}

String _fileName(String path) => path.split(Platform.pathSeparator).last;

String _time() {
  final now = DateTime.now();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(now.hour)}:${two(now.minute)}:${two(now.second)}';
}
