// BuildBeacon Hub — Tests: reading, writing and validating config.json.
// Version 1.4 (2026-11-12) — comments in English.

import 'dart:convert';

import 'package:buildbeacon_core/buildbeacon_core.dart';
import 'package:test/test.dart';

/// The user's layout ([[0,0],[0,1],[1,1]], master tile at [0,1]).
const _example = '''
{
  "version": 1,
  "wled": {"host": "192.168.1.50"},
  "poll_seconds": 45,
  "palette": {"success": "#00ff40", "future_color": "#123456"},
  "tiles": [
    {"id": "master", "label": "BuildBeacon", "kind": "master", "chain_index": 0,
     "pos": {"q": 0, "r": 1}, "zones": {"system": null}},
    {"id": "app", "label": "App", "kind": "project", "chain_index": 1,
     "pos": {"q": 0, "r": 0},
     "zones": {
       "ambient": {"source": {"type": "github", "repo": "acme/app", "workflow": "ci.yml"},
                   "mode": "overall"},
       "dots": {"source": {"type": "github", "repo": "acme/app", "workflow": 12345},
                "mode": "history"}
     }},
    {"id": "site", "label": "Site", "kind": "project", "chain_index": 2,
     "pos": {"q": 1, "r": 1},
     "zones": {"ambient": {"source": {"type": "github", "repo": "acme/site", "branch": "main"},
                           "mode": "overall"},
               "dots": null}}
  ]
}
''';

Config _parse(String json) =>
    Config.fromJson(jsonDecode(json) as Map<String, Object?>);

Map<String, Object?> _tileJson(Map<String, Object?> overrides) => {
  'id': 'x',
  'kind': 'project',
  'chain_index': 1,
  'pos': {'q': 0, 'r': 0},
  ...overrides,
};

/// Translated message of a format error ([fr], [en]: text or matcher).
Matcher _formatError(Object fr, [Object? en]) => throwsA(
  isA<LocalizedFormatException>()
      .having((e) => e.text.resolve('fr'), 'fr', fr)
      .having((e) => e.text.resolve('en'), 'en', en ?? anything),
);

void main() {
  group('lecture', () {
    final config = _parse(_example);

    test('réglages globaux, avec valeurs par défaut', () {
      expect(config.wled.host, '192.168.1.50');
      expect(config.wled.port, 80);
      expect(config.wled.ddpPort, 4048);
      expect(config.wled.brightness, 128);
      expect(config.pollSeconds, 45);
    });

    test('palette : surcharge partielle, clés inconnues ignorées', () {
      expect(config.palette[Status.success], const Rgb(0, 255, 64));
      expect(config.palette[Status.failure], Palette.defaults[Status.failure]);
    });

    test('tuiles, zones et sources', () {
      expect(config.tiles.map((t) => t.id), ['master', 'app', 'site']);
      expect(config.tiles[0].zones, isEmpty);

      final app = config.tiles[1];
      expect(app.pos, const HexPos(0, 0));
      expect(app.kind, TileKind.project);
      expect(app.zones[ZoneName.dots]!.mode, DisplayMode.history);
      final dots = app.zones[ZoneName.dots]!.source;
      expect(dots.type, 'github');
      expect(dots.settings, {'repo': 'acme/app', 'workflow': 12345});

      final site = config.tiles[2].zones[ZoneName.ambient]!.source;
      expect(site.settings, {'repo': 'acme/site', 'branch': 'main'});
    });

    test('config valide, 21 LED', () {
      expect(config.validate(), isEmpty);
      expect(config.ledCount, 21);
    });

    test('objet vide : config par défaut (luminosité 50 %)', () {
      final empty = Config.fromJson(const {});
      expect(empty.wled.host, 'buildbeacon.local');
      expect(empty.wled.brightness, 128);
      expect(empty.pollSeconds, Config.defaultPollSeconds);
      expect(empty.tiles, isEmpty);
    });
  });

  group('aller-retour JSON', () {
    test('lire(écrire(config)) == config', () {
      final first = _parse(_example).toJson();
      final second = _parse(jsonEncode(first)).toJson();
      expect(second, first);
    });

    test('les zones sans action sont écrites à null', () {
      final json = _parse(_example).toJson();
      final tiles = json['tiles']! as List<Object?>;
      final master = tiles[0]! as Map<String, Object?>;
      final site = tiles[2]! as Map<String, Object?>;
      expect(master['zones'], {'system': null});
      expect((site['zones']! as Map<String, Object?>)['dots'], isNull);
    });

    test('config initiale : la master seule, valide', () {
      final initial = Config.initial();
      expect(initial.validate(), isEmpty);
      expect(initial.ledCount, 3);
      expect(_parse(jsonEncode(initial.toJson())).toJson(), initial.toJson());
    });
  });

  group('erreurs de format', () {
    test('version future refusée', () {
      expect(
        () => Config.fromJson(const {'version': 99}),
        _formatError(contains('version 99'), contains('version 99')),
      );
    });

    test(
      'mode inconnu : le numéro de tuile est indiqué, en français et en anglais',
      () {
        final json = {
          'tiles': [
            _tileJson({
              'zones': {
                'ambient': {
                  'source': {'type': 'github', 'repo': 'a/b'},
                  'mode': 'rainbow',
                },
              },
            }),
          ],
        };
        expect(
          () => Config.fromJson(json),
          _formatError(
            'Tuile n° 1 : Mode d\'affichage inconnu : rainbow',
            'Tile #1: Unknown display mode: rainbow',
          ),
        );
      },
    );

    test('champ obligatoire manquant', () {
      expect(
        () => Tile.fromJson(const {'id': 'x', 'kind': 'project'}),
        _formatError(
          'Champ « chain_index » manquant',
          'Missing field "chain_index"',
        ),
      );
    });

    test('couleur mal formée', () {
      expect(() => Rgb.parse('#12345'), throwsFormatException);
      expect(() => Rgb.parse('-00001'), throwsFormatException);
      expect(Rgb.parse('ff8000'), const Rgb(255, 128, 0));
      expect(const Rgb(255, 128, 0).toHex(), '#FF8000');
    });
  });

  group('validation', () {
    Config withTiles(List<Map<String, Object?>> tiles) => Config.fromJson({
      'tiles': [
        {
          'id': 'master',
          'kind': 'master',
          'chain_index': 0,
          'pos': {'q': 9, 'r': 9},
        },
        ...tiles,
      ],
    });

    test('deux tuiles au même rang de chaîne', () {
      final config = withTiles([
        _tileJson({
          'id': 'a',
          'pos': {'q': 0, 'r': 0},
        }),
        _tileJson({
          'id': 'b',
          'pos': {'q': 1, 'r': 0},
        }),
      ]);
      expect(config.validate().resolveAll('fr'), [
        'Deux tuiles au même rang dans la chaîne : 1',
      ]);
      expect(config.validate().resolveAll('en'), [
        'Two tiles at the same chain position: 1',
      ]);
    });

    test('deux tuiles à la même place, identifiant en double', () {
      final config = withTiles([
        _tileJson({'id': 'a', 'chain_index': 1}),
        _tileJson({'id': 'a', 'chain_index': 2}),
      ]);
      expect(
        config.validate().resolveAll('fr'),
        unorderedEquals([
          'Identifiant de tuile en double : « a »',
          'Deux tuiles à la même place au mur : (0, 0)',
        ]),
      );
    });

    test('master hors de la tête de chaîne, tuile projet au rang 0', () {
      final config = Config.fromJson({
        'tiles': [
          {
            'id': 'master',
            'kind': 'master',
            'chain_index': 1,
            'pos': {'q': 9, 'r': 9},
          },
          _tileJson({'chain_index': 0}),
        ],
      });
      expect(
        config.validate().resolveAll('fr'),
        unorderedEquals([
          contains('position 0'),
          contains('position de chaîne ≥ 1'),
        ]),
      );
    });

    test('il faut exactement une master', () {
      final config = Config.fromJson({
        'tiles': [_tileJson({})],
      });
      expect(config.validate().resolveAll('fr'), [
        contains('exactement une tuile master'),
      ]);
    });

    test(
      'historique impossible en ambiance, zone points absente de la master',
      () {
        final action = {
          'source': {'type': 'github', 'repo': 'acme/app'},
          'mode': 'history',
        };
        final config = Config.fromJson({
          'tiles': [
            {
              'id': 'master',
              'kind': 'master',
              'chain_index': 0,
              'pos': {'q': 9, 'r': 9},
              'zones': {'dots': action},
            },
            _tileJson({
              'label': 'App',
              'zones': {'ambient': action},
            }),
          ],
        });
        expect(
          config.validate().resolveAll('fr'),
          unorderedEquals([
            'Tuile « master » : pas de zone « points » sur une tuile master',
            'Tuile « App » : mode « historique » impossible dans la zone '
                'ambiance',
          ]),
        );
        expect(
          config.validate().resolveAll('en'),
          unorderedEquals([
            'Tile "master": no dots zone on a master tile',
            'Tile "App": "history" mode is not available in the ambient zone',
          ]),
        );
      },
    );

    test('sans registre de plugins, les réglages ne sont pas vérifiés', () {
      final config = withTiles([
        _tileJson({
          'label': 'App',
          'zones': {
            'ambient': {
              'source': {
                'type': 'github',
                'repo': 'https://github.com/acme/app',
              },
              'mode': 'overall',
            },
          },
        }),
      ]);
      expect(config.validate(), isEmpty);
    });

    test('scrutation trop rapide, luminosité hors limites', () {
      final config = Config.fromJson({
        'poll_seconds': 2,
        'wled': {'brightness': 300},
        'tiles': [
          {
            'id': 'master',
            'kind': 'master',
            'chain_index': 0,
            'pos': {'q': 0, 'r': 0},
          },
        ],
      });
      expect(config.validate(), hasLength(2));
    });
  });

  group('source', () {
    test('réglages à plat en JSON, textes nettoyés, vides retirés', () {
      final source = SourceConfig.fromJson(const {
        'type': ' github ',
        'repo': ' acme/app ',
        'workflow': '',
        'branch': '  ',
      });
      expect(source.type, 'github');
      expect(source.settings, {'repo': 'acme/app'});
      expect(source.toJson(), {'type': 'github', 'repo': 'acme/app'});
    });

    test('la clé ne dépend pas de l\'ordre des réglages', () {
      final a = SourceConfig(
        type: 'github',
        settings: {'repo': 'acme/app', 'branch': 'main'},
      );
      final b = SourceConfig(
        type: 'github',
        settings: {'branch': 'main', 'repo': 'acme/app'},
      );
      expect(a.key, b.key);
    });

    test('la clé distingue le type et les réglages', () {
      SourceConfig github(Map<String, Object?> settings) =>
          SourceConfig(type: 'github', settings: settings);
      final keys = {
        github({'repo': 'acme/app'}).key,
        github({'repo': 'acme/app', 'workflow': 'ci.yml'}).key,
        github({'repo': 'acme/app', 'branch': 'main'}).key,
        github({'repo': 'acme/app', 'branch': ''}).key,
        SourceConfig(type: 'gitlab', settings: {'repo': 'acme/app'}).key,
      };
      expect(keys, hasLength(4));
    });
  });
}
