<!-- BuildBeacon — README (English). Version 1.0 (2026-11-11) -->
# BuildBeacon

[![check](https://github.com/devcafeine/buildbeacon/actions/workflows/check.yml/badge.svg)](https://github.com/devcafeine/buildbeacon/actions/workflows/check.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

**A wall of glowing hexagonal tiles that shows the state of your GitHub Actions — and
anything else a plugin can read.**

[Version française](README.fr.md)

Each 3D-printed tile has its own LEDs. A tile follows a project: its top and bottom strips
glow with the overall state (green, red, pulsing orange while a run is in progress), and
its five dots show the last five runs. The master tile, which holds the ESP32, shows the
state of the system.

> **Status: early development.** The core works and is tested (tile model, LED rendering,
> GitHub plugin, output to WLED, simulator, test pattern). The program that runs everything
> from `config.json`, the REST API, the web interface and the Docker image are next.

## How it works

```
GitHub API ──(polling, ETag)──┐
                              ▼
              ┌──────────── Hub (Dart) ─────────────┐
              │  source plugins → state cache       │
              │        ↓                            │
              │  LED frame (20 fps)                 │──DDP/UDP──▶ ESP32 + WLED ──▶ tiles
              │  REST API + web interface (soon)    │
              └─────────────────────────────────────┘
```

- **Hardware**: WS2812B LEDs on a single data line, driven by an ESP32-C3 running
  [WLED](https://kno.wled.ge/). No custom firmware: WLED only receives the colors.
- **Hub**: a Dart program (Docker image soon) that reads the sources through **plugins**,
  computes the color of every LED and streams the frames to WLED over DDP.
- **Plugins**: GitHub Actions first. Anyone can add a source (another CI, a 3D printer, a
  web service…) with the plugin SDK — see [Writing a plugin](docs/writing-a-plugin.md).

## The tiles

| Tile | LEDs | Zones |
|---|---|---|
| Master (logo, holds the ESP32) | 3 | `system` |
| Project tile | 9 | `ambient`: top and bottom strips (4 LEDs) · `dots`: 5 dots (left → right) |

Tiles are chained in wiring order: the master first (LEDs 0–2), then project tile #k uses
LEDs `3 + 9·(k−1)` to `3 + 9·k − 1`. The wiring order is independent from the place on the
wall: `config.json` stores both.

Display modes: `overall` (color of the current state), `history` (last 5 runs on the dots),
`thresholds` (a measurement compared to thresholds), `gauge` (progress bar on the dots).

The 3D models and circuit boards will be published later under CERN-OHL-P-2.0.

## Quick start (developers)

Requirements: [mise](https://mise.jdx.dev/), which installs the right Flutter/Dart SDK.

```sh
git clone https://github.com/devcafeine/buildbeacon.git
cd buildbeacon
mise install        # Flutter 3.47.6 (Dart 3.13.5)
mise run get        # dependencies of the whole workspace
mise run check      # format, static analysis, tests
```

### Without hardware: the simulator

The simulator is a fake WLED that shows the tiles in a web page.

```sh
mise run simulator -- --open                    # terminal 1: http://localhost:8090
mise run test-pattern -- --host 127.0.0.1       # terminal 2: sends a test pattern
```

Options: `mise run simulator -- --help`. Add `--config <config.json>` to see your real
layout, `--terminal` to draw in the terminal.

### With the tiles

1. Flash [WLED](https://install.wled.me/) on the ESP32-C3, then in its web interface:
   - *LED Preferences*: data GPIO 4, type WS281x, color order GRB, length = 3 + 9 × number
     of project tiles, maximum current of your power supply;
   - *WiFi Setup*: your network, mDNS name `buildbeacon` (→ `buildbeacon.local`);
   - *Sync Interfaces*: "Receive UDP realtime" enabled (default).
2. Check the wiring and find the chain order:
   `mise run test-pattern -- --host buildbeacon.local` (or the IP of WLED).

## Configuration

`config.json` (edited from the web interface, soon):

```json
{
  "version": 1,
  "wled": { "host": "buildbeacon.local", "brightness": 128 },
  "poll_seconds": 30,
  "tiles": [
    { "id": "master", "label": "BuildBeacon", "kind": "master", "chain_index": 0,
      "pos": { "q": 0, "r": 1 }, "zones": { "system": null } },
    { "id": "app", "label": "App", "kind": "project", "chain_index": 1,
      "pos": { "q": 0, "r": 0 },
      "zones": {
        "ambient": { "source": { "type": "github", "repo": "owner/app", "workflow": "ci.yml" },
                     "mode": "overall" },
        "dots":    { "source": { "type": "github", "repo": "owner/app", "workflow": "ci.yml" },
                     "mode": "history" } } }
  ]
}
```

Secrets never go into `config.json`: the GitHub token (fine-grained, read-only, *Actions:
read* and *Metadata: read*) is given through the `BB_GITHUB_TOKEN` environment variable —
see [`.env.example`](.env.example).

## Languages

The interfaces are available in English and French (`BB_LANG=en` or `BB_LANG=fr` for the
command-line tools, browser language for the web pages). Plugins bring their own
translations.

## Repository

```
hub/                 Dart workspace
  sdk/               plugin SDK (the only dependency of a plugin)
  core/              model, LED rendering, plugin registry
  plugins/github/    GitHub Actions plugin
  server/            plugin runner, DDP output, simulator, test pattern
  tool/              new_plugin.dart (mise run new-plugin <name>)
docs/                guides
```

## Contributing

Bug reports, ideas, plugins and translations are welcome: see
[CONTRIBUTING.md](CONTRIBUTING.md) and [Writing a plugin](docs/writing-a-plugin.md).

## License

Software: [MIT](LICENSE). Hardware (3D models, boards, published later): CERN-OHL-P-2.0.
