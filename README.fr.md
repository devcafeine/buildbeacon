<!-- BuildBeacon — README (français). Version 1.0 (2026-11-11) -->
# BuildBeacon

[![check](https://github.com/devcafeine/buildbeacon/actions/workflows/check.yml/badge.svg)](https://github.com/devcafeine/buildbeacon/actions/workflows/check.yml)
[![Licence : MIT](https://img.shields.io/badge/licence-MIT-blue.svg)](LICENSE)

**Un mur de tuiles hexagonales lumineuses qui affiche l'état de vos GitHub Actions — et
tout ce qu'un plugin sait lire.**

[English version](README.md)

Chaque tuile, imprimée en 3D, a ses propres LED. Une tuile suit un projet : ses rubans du
haut et du bas prennent la couleur de l'état global (vert, rouge, orange qui pulse pendant
un run), et ses cinq points montrent les cinq derniers runs. La tuile master, qui contient
l'ESP32, affiche l'état du système.

> **État : début du développement.** Le cœur fonctionne et il est testé (modèle des tuiles,
> rendu des LED, plugin GitHub, sortie vers WLED, simulateur, mire). Le programme qui fait
> tout tourner à partir de `config.json`, l'API REST, l'interface web et l'image Docker
> arrivent ensuite.

## Fonctionnement

```
API GitHub ──(scrutation, ETag)──┐
                                 ▼
              ┌──────────── Hub (Dart) ─────────────┐
              │  plugins de source → cache d'états  │
              │        ↓                            │
              │  image des LED (20 img/s)           │──DDP/UDP──▶ ESP32 + WLED ──▶ tuiles
              │  API REST + interface web (bientôt) │
              └─────────────────────────────────────┘
```

- **Matériel** : LED WS2812B sur une seule ligne de données, pilotées par un ESP32-C3 sous
  [WLED](https://kno.wled.ge/). Pas de firmware maison : WLED reçoit seulement les couleurs.
- **Hub** : un programme Dart (bientôt en image Docker) qui lit les sources grâce à des
  **plugins**, calcule la couleur de chaque LED et envoie les images à WLED en DDP.
- **Plugins** : GitHub Actions d'abord. Chacun peut ajouter une source (une autre CI, une
  imprimante 3D, un service web…) avec le SDK des plugins — voir
  [Écrire un plugin](docs/writing-a-plugin.fr.md).

## Les tuiles

| Tuile | LED | Zones |
|---|---|---|
| Master (logo, contient l'ESP32) | 3 | `system` |
| Tuile projet | 9 | `ambient` : rubans du haut et du bas (4 LED) · `dots` : 5 points (gauche → droite) |

Les tuiles sont chaînées dans l'ordre du câblage : la master d'abord (LED 0 à 2), puis la
tuile projet n° k occupe les LED `3 + 9·(k−1)` à `3 + 9·k − 1`. L'ordre de câblage ne dépend
pas de la place au mur : `config.json` garde les deux.

Modes d'affichage : `overall` (couleur de l'état actuel), `history` (5 derniers runs sur les
points), `thresholds` (une mesure comparée à des seuils), `gauge` (barre de progression sur
les points).

Les modèles 3D et les cartes électroniques seront publiés plus tard sous CERN-OHL-P-2.0.

## Démarrage rapide (développeurs)

Prérequis : [mise](https://mise.jdx.dev/), qui installe le bon SDK Flutter/Dart.

```sh
git clone https://github.com/devcafeine/buildbeacon.git
cd buildbeacon
mise install        # Flutter 3.47.6 (Dart 3.13.5)
mise run get        # dépendances de tout l'espace de travail
mise run check      # format, analyse statique, tests
```

### Sans matériel : le simulateur

Le simulateur est un faux WLED qui montre les tuiles dans une page web.

```sh
mise run simulator -- --open                    # terminal 1 : http://localhost:8090
mise run test-pattern -- --host 127.0.0.1       # terminal 2 : envoie une mire
```

Options : `mise run simulator -- --help`. Ajouter `--config <config.json>` pour voir votre
vraie disposition, `--terminal` pour dessiner dans le terminal.

### Avec les tuiles

1. Installer [WLED](https://install.wled.me/) sur l'ESP32-C3, puis dans son interface web :
   - *LED Preferences* : GPIO de données 4, type WS281x, ordre GRB, longueur = 3 + 9 × nombre
     de tuiles projet, courant maximal de votre alimentation ;
   - *WiFi Setup* : votre réseau, nom mDNS `buildbeacon` (→ `buildbeacon.local`) ;
   - *Sync Interfaces* : « Receive UDP realtime » activé (par défaut).
2. Vérifier le câblage et relever l'ordre de chaînage :
   `mise run test-pattern -- --host buildbeacon.local` (ou l'IP de WLED).

## Configuration

`config.json` (bientôt modifiable depuis l'interface web) :

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

Les secrets ne vont jamais dans `config.json` : le jeton GitHub (*fine-grained*, lecture
seule, *Actions: read* et *Metadata: read*) passe par la variable d'environnement
`BB_GITHUB_TOKEN` — voir [`.env.example`](.env.example).

## Langues

Les interfaces existent en anglais et en français (`BB_LANG=fr` ou `BB_LANG=en` pour les
outils en ligne de commande, langue du navigateur pour les pages web). Les plugins apportent
leurs propres traductions.

## Le dépôt

```
hub/                 espace de travail Dart
  sdk/               SDK des plugins (seule dépendance d'un plugin)
  core/              modèle, rendu des LED, registre des plugins
  plugins/github/    plugin GitHub Actions
  server/            exécution des plugins, sortie DDP, simulateur, mire
  tool/              new_plugin.dart (mise run new-plugin <nom>)
docs/                guides
```

## Participer

Signalements de bugs, idées, plugins et traductions sont les bienvenus : voir
[CONTRIBUTING.fr.md](CONTRIBUTING.fr.md) et [Écrire un plugin](docs/writing-a-plugin.fr.md).

## Licence

Logiciel : [MIT](LICENSE). Matériel (modèles 3D, cartes, publiés plus tard) : CERN-OHL-P-2.0.
