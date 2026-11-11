<!-- BuildBeacon — writing a plugin (English). Version 1.1 (2026-11-11) — trying a plugin with mise run hub. -->
# Writing a plugin

[Version française](writing-a-plugin.fr.md)

A **source plugin** teaches BuildBeacon to read something new: another CI, a 3D printer, a
web service, a home sensor… This guide walks you through a complete plugin, from the
template to the pull request. The GitHub Actions plugin (`hub/plugins/github/`) is a real
example to read alongside.

## What the Hub does for you

You only write how to **read** your source. The Hub takes care of the rest:

- one connection per distinct source, even if several tiles follow it;
- the state cache, the LED rendering, the animations;
- validating the settings typed by the user, and generating the form in the interface;
- secrets: read from the environment, only those your plugin declares are given to it.

A plugin depends only on the **plugin SDK** (`package:buildbeacon_plugin_sdk`). It is
compiled into the Hub image and arrives through a pull request.

> Coming later: "external" plugins in any language, through a generic HTTP JSON source and
> an incoming webhook. This guide covers Dart plugins.

## What a plugin provides

A source fills what it knows in a `SourceState`:

| Field | Meaning | Display modes it unlocks |
|---|---|---|
| `status` | current state: `success`, `warning`, `failure`, `running`, `queued`, `cancelled`, `unknown` | `overall` |
| `history` | past states, most recent first | `history` (last 5 on the dots) |
| `metrics` | named measurements (`progress`, `nozzle_temp`…) | `thresholds`, `gauge` |

`running` and `queued` pulse on the tiles. The colors are chosen by the user (palette).

## 1. Create the plugin

```sh
mise run new-plugin octoprint
```

This creates `hub/plugins/octoprint/` — a plugin that already works (it polls a URL), its
tests and a README — and registers it in the Hub (workspace, server dependency, list of
built-in plugins). Run `mise run check`: everything is green from the start.

## 2. Describe it

```dart
final class OctoprintPlugin extends SourcePlugin {
  const OctoprintPlugin();

  @override
  String get type => 'octoprint';            // "type" in config.json: lowercase, digits, _

  @override
  LocalizedText get label => const LocalizedText.same('OctoPrint');

  @override
  LocalizedText get description => const LocalizedText({
    'en': 'State and progress of the current print.',
    'fr': 'État et avancement de l\'impression en cours.',
  });
  // …
}
```

**Texts shown to users are `LocalizedText`**: English is required (fallback language),
French is welcome.

- `const LocalizedText({'en': '…', 'fr': '…'})` — a fixed label;
- `const LocalizedText.same('OctoPrint')` — same text in every language;
- `LocalizedText.build((l) => tr(l, en: '…$value', fr: '…$value'))` — a message that
  contains values, built in the reader's language.

Identifiers (type, setting keys, metric ids) are in English.

### Settings

Each `SettingField` becomes a field of the form and a key of the source in `config.json`:

| Parameter | Role |
|---|---|
| `id` | key in `config.json` (`"url"`), lowercase, digits, `_`; `type` is reserved |
| `label`, `help` | label and help of the field (`LocalizedText`) |
| `kind` | `text` (default), `integer`, `number`, `boolean`, `choice` (with `choices`) |
| `required` | the source does not open without it |
| `placeholder` | example shown in the empty field |
| `pattern`, `patternHint` | regular expression a text must match, and the expected format in plain words |

```dart
@override
List<SettingField> get settings => const [
  SettingField(
    id: 'url',
    label: LocalizedText({'en': 'OctoPrint address', 'fr': 'Adresse d\'OctoPrint'}),
    required: true,
    placeholder: 'http://octopi.local',
    pattern: r'https?://\S+',
    patternHint: LocalizedText.same('http(s)://…'),
  ),
];
```

The Hub refuses an unknown setting (a typo would otherwise be silently ignored). For checks
across several settings, override `validateSettings` — it is only called when every field
is valid.

### Secrets

Tokens and access codes never go into `config.json`: they come from environment variables
prefixed with `BB_`.

```dart
@override
List<SecretField> get secrets => const [
  SecretField(
    env: 'BB_OCTOPRINT_API_KEY',
    label: LocalizedText({'en': 'API key', 'fr': 'Clé d\'API'}),
    required: true,       // the Hub does not open the source without it
  ),
];
```

### What you provide

```dart
@override
bool get providesHistory => false;     // true if you fill `history`

@override
List<MetricInfo> get metrics => const [
  MetricInfo(id: 'progress', label: LocalizedText({'en': 'Progress', 'fr': 'Progression'}),
      unit: '%', min: 0, max: 100),
  MetricInfo(id: 'time_left', label: LocalizedText({'en': 'Time left', 'fr': 'Temps restant'}),
      unit: 'min'),
];
```

The interface only offers the display modes your plugin can feed, and the Hub refuses the
others with a clear message.

## 3. Read the source

Most sources are polled. `pollingStream` reads right away, then after each interval (set
by the user), and stops when the Hub no longer needs the source:

```dart
@override
Stream<SourceState> connect(SourceSettings settings, PluginContext context) {
  final url = Uri.parse(settings.text('url')).resolve('/api/job');
  final apiKey = context.secret(apiKeyEnv)!; // required: checked by the Hub
  return pollingStream(context.pollInterval, (previous) async {
    final response = await context.httpClient.get(url, headers: {'X-Api-Key': apiKey});
    // … read the response, return a SourceState
  });
}
```

- **`SourceSettings`**: the settings, already validated, with typed accessors (`text`,
  `optionalText`, `integer`, `number`, `flag`…).
- **`PluginContext`**: shared HTTP client (`httpClient`), polling interval, `secret(env)`,
  clock `now()` (use it instead of `DateTime.now()`, for the tests), `log()` (technical
  log, in English).
- **`previous`**: the previous state. Handy with conditional requests: on an HTTP 304
  answer, keep `previous.history`.
- **Errors**: throw a `SourceException` with a translated message that says what to fix.
  The panel keeps the last known state and the interface shows the message. Any other
  exception becomes an "unexpected error".

```dart
if (response.statusCode == 403) {
  throw const SourceException(LocalizedText({
    'en': 'OctoPrint refused the API key (403): check BB_OCTOPRINT_API_KEY',
    'fr': 'OctoPrint refuse la clé d\'API (403) : vérifier BB_OCTOPRINT_API_KEY',
  }));
}
```

**Be gentle with the service**: respect its quotas, use conditional requests (ETag) when
it supports them, never poll faster than the interval you are given.

**Push sources** (MQTT, websocket, server-sent events): return your own `Stream` instead of
`pollingStream`. It must release everything (connection, timers) when the Hub cancels the
subscription.

## 4. Test it

The SDK comes with testing tools, so no network and no Hub are needed:

```dart
import 'package:buildbeacon_plugin_sdk/testing.dart';

test('follows the Hub rules', () {
  expect(conformanceIssues(plugin), isEmpty);
});

test('the address is required', () {
  expect(settingsIssues(plugin, {}).resolveAll('en'), ['"OctoPrint address" is required']);
});

test('printing at 62 %', () async {
  final state = await firstState(
    plugin,
    {'url': 'http://octopi.local'},
    context: fakeContext(
      secrets: {'BB_OCTOPRINT_API_KEY': 'test-key'},
      respond: (request) => http.Response(
        jsonEncode({'state': 'Printing', 'progress': {'completion': 62.0, 'printTimeLeft': 1800}}),
        200,
      ),
    ),
  );
  expect(state.status, Status.running);
  expect(state.metric('progress')?.value, 62);
});
```

| Tool | Role |
|---|---|
| `conformanceIssues(plugin)` | the rules the Hub checks when loading plugins (identifiers, English translations, secrets…) |
| `settingsIssues(plugin, settings)` | the validation the Hub applies to the settings (translated messages: `resolveAll('en')`) |
| `fakeContext(respond:, secrets:, clock:, pollInterval:)` | fake HTTP (without `respond`, any request fails), secrets, clock |
| `firstState` / `firstStates` | open the plugin like the Hub does and return the first state(s) |

Test the success cases, the errors (each `SourceException`) and the unusual answers. Never
use real secrets or the real service in the tests.

## 5. Use it in `config.json`

```json
"zones": {
  "ambient": { "source": { "type": "octoprint", "url": "http://octopi.local" },
               "mode": "overall" },
  "dots":    { "source": { "type": "octoprint", "url": "http://octopi.local" },
               "mode": "gauge", "options": { "metric": "progress" } }
}
```

Both zones use the same source: the Hub opens a single connection. The `gauge` lights the
five dots from left to right, the last one partially; `thresholds` would color the zone
according to a measurement (`"thresholds": {"warning": 240, "failure": 260}`).

To see it live: add the source to `data/config.json` (copied from `config.example.json`)
and run `mise run hub` — with the simulator (`mise run simulator -- --open`) if you have
no tiles. The Hub reloads the file when you save it and logs every change of state of
your source, including its error messages.

## 6. Open a pull request

- [ ] `mise run check` passes;
- [ ] a `conformanceIssues` test, tests for the settings, the success cases and the errors;
- [ ] English texts (required) and French texts (welcome);
- [ ] the plugin README filled in: what it watches, settings, secrets, example;
- [ ] no secret in the code or the tests;
- [ ] gentle with the service (interval, quotas);
- [ ] version lines updated in the files you touched.

See also [CONTRIBUTING.md](../CONTRIBUTING.md).

## Complete example: OctoPrint

```dart
// BuildBeacon Hub — Plugin OctoPrint.
// Version 1.0 (2026-11-11)

import 'dart:convert';

import 'package:buildbeacon_plugin_sdk/buildbeacon_plugin_sdk.dart';

/// OctoPrint: state and progress of the current print.
final class OctoprintPlugin extends SourcePlugin {
  const OctoprintPlugin();

  static const apiKeyEnv = 'BB_OCTOPRINT_API_KEY';

  @override
  String get type => 'octoprint';

  @override
  LocalizedText get label => const LocalizedText.same('OctoPrint');

  @override
  LocalizedText get description => const LocalizedText({
    'en': 'State and progress of the current print.',
    'fr': 'État et avancement de l\'impression en cours.',
  });

  @override
  List<SettingField> get settings => const [
    SettingField(
      id: 'url',
      label: LocalizedText({'en': 'OctoPrint address', 'fr': 'Adresse d\'OctoPrint'}),
      required: true,
      placeholder: 'http://octopi.local',
      pattern: r'https?://\S+',
      patternHint: LocalizedText.same('http(s)://…'),
    ),
  ];

  @override
  List<SecretField> get secrets => const [
    SecretField(
      env: apiKeyEnv,
      label: LocalizedText({'en': 'API key', 'fr': 'Clé d\'API'}),
      required: true,
    ),
  ];

  @override
  List<MetricInfo> get metrics => const [
    MetricInfo(
      id: 'progress',
      label: LocalizedText({'en': 'Progress', 'fr': 'Progression'}),
      unit: '%',
      min: 0,
      max: 100,
    ),
    MetricInfo(
      id: 'time_left',
      label: LocalizedText({'en': 'Time left', 'fr': 'Temps restant'}),
      unit: 'min',
    ),
  ];

  @override
  Stream<SourceState> connect(SourceSettings settings, PluginContext context) {
    final url = Uri.parse(settings.text('url')).resolve('/api/job');
    final apiKey = context.secret(apiKeyEnv)!; // required: checked by the Hub
    return pollingStream(context.pollInterval, (_) async {
      final response = await context.httpClient.get(
        url,
        headers: {'X-Api-Key': apiKey},
      );
      if (response.statusCode == 403) {
        throw const SourceException(
          LocalizedText({
            'en': 'OctoPrint refused the API key (403): check BB_OCTOPRINT_API_KEY',
            'fr': 'OctoPrint refuse la clé d\'API (403) : vérifier BB_OCTOPRINT_API_KEY',
          }),
        );
      }
      if (response.statusCode != 200) {
        final code = response.statusCode;
        throw SourceException(
          LocalizedText.build(
            (l) => tr(l, en: 'OctoPrint answered $code', fr: 'OctoPrint a répondu $code'),
          ),
        );
      }

      final json = jsonDecode(response.body);
      final state = switch (json) {
        {'state': final String s} => s,
        _ => '',
      };
      final completion = switch (json) {
        {'progress': {'completion': final num c}} => c.toDouble(),
        _ => null,
      };
      final secondsLeft = switch (json) {
        {'progress': {'printTimeLeft': final num t}} => t,
        _ => null,
      };
      return SourceState(
        status: _status(state),
        metrics: {
          if (completion != null)
            'progress': Metric(completion, unit: '%', min: 0, max: 100),
          if (secondsLeft != null)
            'time_left': Metric(secondsLeft / 60, unit: 'min'),
        },
        updatedAt: context.now(),
      );
    });
  }

  static Status _status(String state) => switch (state) {
    'Printing' || 'Finishing' => Status.running,
    'Pausing' || 'Paused' => Status.warning,
    'Error' || 'Offline after error' => Status.failure,
    'Cancelling' => Status.cancelled,
    'Operational' => Status.success,
    _ => Status.unknown,
  };
}
```

## SDK reference

| Element | Role |
|---|---|
| `SourcePlugin` | the contract: `type`, `label`, `description`, `settings`, `secrets`, `providesHistory`, `metrics`, `dynamicMetrics`, `validateSettings`, `connect`, `describe` |
| `SettingField`, `SettingKind` | a setting of the source |
| `SecretField` | a secret read from a `BB_…` environment variable |
| `MetricInfo` | a measurement the plugin can provide |
| `SourceSettings` | typed access to the settings |
| `PluginContext` | HTTP client, polling interval, secrets, clock, log |
| `SourceState`, `Metric`, `Status` | what the plugin returns |
| `SourceException` | a read error with a translated message |
| `pollingStream` | polling loop with error handling |
| `LocalizedText`, `tr`, `resolveAll` | translated texts |
| `settingsIssues`, `conformanceIssues` | the Hub's validations |
| `testing.dart`: `fakeContext`, `firstState`, `firstStates` | testing tools |

The SDK sources are in [`hub/sdk/lib/`](../hub/sdk/lib/), with comments on every element.
