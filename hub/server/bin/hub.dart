// BuildBeacon Hub — Main program: config.json → plugins → LED frame → WLED, and REST API.
// Version 1.3 (2026-11-12) — comments in English.

import 'dart:async';
import 'dart:io';

import 'package:buildbeacon_core/buildbeacon_core.dart';
import 'package:buildbeacon_hub/buildbeacon_hub.dart';
import 'package:buildbeacon_hub/src/cli.dart';
import 'package:buildbeacon_plugin_github/buildbeacon_plugin_github.dart';
import 'package:http/http.dart' as http;
import 'package:shelf/shelf_io.dart' as shelf_io;

String _usage(String l) => tr(
  l,
  en: '''
BuildBeacon Hub: reads config.json, runs the source plugins, sends the LED
frames to WLED (or to the simulator) and serves the REST API. Reloads
config.json when it changes.

Usage: mise run hub [-- options]          (at the repository root: uses
                                          data/config.json and .env)
       dart run bin/hub.dart [options]    (in hub/server)

Options:
  --config <file>     configuration (default: BB_CONFIG, otherwise /data/config.json);
                      created with the master tile only if missing
  --env-file <file>   variables file such as .env (optional; real environment
                      variables take precedence)
  --port <n>          HTTP port of the API (default: BB_PORT, otherwise 8080)
  --listen <address>  listening address (default: BB_LISTEN, otherwise 0.0.0.0,
                      all interfaces; 127.0.0.1 for this machine only)
  --web <folder>      web interface files to serve (default: BB_WEB_DIR)
  --help              this help

Secrets: BB_GITHUB_TOKEN (optional for public repositories, 60 requests per hour
without it); BB_API_TOKEN (optional: protects the API writes).
Language: BB_LANG=fr or BB_LANG=en (default: system language).''',
  fr: '''
BuildBeacon Hub : lit config.json, fait tourner les plugins de source, envoie
les images des LED à WLED (ou au simulateur) et sert l'API REST. Recharge
config.json quand il change.

Usage : mise run hub [-- options]          (à la racine du dépôt : utilise
                                           data/config.json et .env)
        dart run bin/hub.dart [options]    (dans hub/server)

Options :
  --config <fichier>    configuration (défaut : BB_CONFIG, sinon /data/config.json) ;
                        créée avec la tuile master seule si elle n'existe pas
  --env-file <fichier>  fichier de variables comme .env (facultatif ; les vraies
                        variables d'environnement ont priorité)
  --port <n>            port HTTP de l'API (défaut : BB_PORT, sinon 8080)
  --listen <adresse>    adresse d'écoute (défaut : BB_LISTEN, sinon 0.0.0.0,
                        toutes les interfaces ; 127.0.0.1 pour cette machine seule)
  --web <dossier>       fichiers de l'interface web à servir (défaut : BB_WEB_DIR)
  --help                cette aide

Secrets : BB_GITHUB_TOKEN (facultatif pour les dépôts publics, 60 requêtes par
heure sans lui) ; BB_API_TOKEN (facultatif : protège les écritures de l'API).
Langue : BB_LANG=fr ou BB_LANG=en (défaut : langue du système).''',
);

Future<void> main(List<String> args) async {
  final systemLanguage = cliLanguage();
  final usage = _usage(systemLanguage);
  final options = parseOptions(
    args,
    usage: usage,
    language: systemLanguage,
    withValue: {'config', 'env-file', 'port', 'listen', 'web'},
  );
  final environment = await loadEnvironment(envFile: options['env-file']);
  // BB_LANG may come from the .env file.
  final l = environment['BB_LANG'] == null
      ? systemLanguage
      : languageOf(environment['BB_LANG']);
  void log(LocalizedText message) =>
      stdout.writeln('${_time()} ${message.resolve(l)}');

  final configPath =
      options['config'] ?? environment['BB_CONFIG'] ?? '/data/config.json';
  final port = intOption(
    {'port': options['port'] ?? environment['BB_PORT']},
    'port',
    8080,
    usage: usage,
    language: l,
  );
  final listen = options['listen'] ?? environment['BB_LISTEN'] ?? '0.0.0.0';
  final webDir = options['web'] ?? environment['BB_WEB_DIR'];
  final apiToken = environment['BB_API_TOKEN'];

  final plugins = builtinPlugins();
  // First start: no config.json → the master tile only, to be set up from
  // the interface. An existing but invalid file is never replaced.
  final ({Config config, bool created}) loaded;
  try {
    loaded = await readOrCreateConfigFile(configPath);
  } on LocalizedFormatException catch (e) {
    fail(e.text.resolve(l));
  } on FileSystemException catch (e) {
    final reason = e.osError?.message ?? e.message;
    fail(
      tr(
        l,
        en: 'Cannot create $configPath ($reason)',
        fr: 'Impossible de créer $configPath ($reason)',
      ),
    );
  }
  final config = loaded.config;
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
  final service = HubService(
    hub: hub,
    configPath: configPath,
    environment: environment,
    log: log,
  );

  final HttpServer server;
  try {
    server = await shelf_io.serve(
      hubHandler(service, apiToken: apiToken, webDir: webDir),
      listen,
      port,
    );
  } on SocketException catch (e) {
    await hub.stop();
    httpClient.close();
    final reason = e.osError?.message ?? e.message;
    fail(
      tr(
        l,
        en:
            'Cannot listen on $listen:$port ($reason). Choose another port '
            'with --port.',
        fr:
            'Impossible d\'écouter sur $listen:$port ($reason). Choisir un '
            'autre port avec --port.',
      ),
    );
  }
  final shown = listen == '0.0.0.0' ? 'localhost' : listen;
  log(
    LocalizedText.build(
      (l) => tr(
        l,
        en:
            'API: http://$shown:${server.port}/api — writes '
            '${apiToken == null ? 'not protected (BB_API_TOKEN not set)' : 'protected by BB_API_TOKEN'}',
        fr:
            'API : http://$shown:${server.port}/api — écritures '
            '${apiToken == null ? 'non protégées (BB_API_TOKEN absent)' : 'protégées par BB_API_TOKEN'}',
      ),
    ),
  );

  if (loaded.created) {
    final url = 'http://$shown:${server.port}';
    log(
      LocalizedText.build(
        (l) => tr(
          l,
          en:
              'No configuration yet: $configPath created with the master tile '
              'only. Add and set up the tiles from the web interface ($url), '
              'or start from config.example.json (three public repositories).',
          fr:
              'Pas encore de configuration : $configPath créé avec la tuile '
              'master seule. Ajoutez et réglez les tuiles depuis l\'interface '
              'web ($url), ou partez de config.example.json (trois dépôts '
              'publics).',
        ),
      ),
    );
  }

  // Hot reload: watch the folder, because many editors replace the file
  // instead of rewriting it. A configuration the API has just saved is
  // identical: the service ignores it.
  final file = File(configPath).absolute;
  final name = _fileName(file.path);
  Timer? debounce;
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
          () => unawaited(service.reloadFromDisk()),
        );
      });

  // Clean shutdown: Ctrl-C, or SIGTERM sent by Docker.
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
  await server.close(force: true);
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
