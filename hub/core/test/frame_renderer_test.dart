// BuildBeacon Hub — Tests : calcul de l'image des LED.
// Version 1.3 (2026-11-11) — identifiants en anglais (modes, zones, états).

import 'package:buildbeacon_core/buildbeacon_core.dart';
import 'package:test/test.dart';

final _app = SourceConfig(
  type: 'github',
  settings: {'repo': 'acme/app', 'workflow': 'ci.yml'},
);
final _site = SourceConfig(
  type: 'github',
  settings: {'repo': 'acme/site', 'branch': 'main'},
);

/// Disposition de l'utilisateur : master en (0, 1), tuiles en (0, 0) et (1, 1).
Config _config() => Config(
  tiles: [
    Tile(
      id: 'master',
      label: 'BuildBeacon',
      kind: TileKind.master,
      chainIndex: 0,
      pos: const HexPos(0, 1),
      zones: {
        ZoneName.system: ZoneAction(source: _site, mode: DisplayMode.overall),
      },
    ),
    Tile(
      id: 'app',
      label: 'App',
      kind: TileKind.project,
      chainIndex: 1,
      pos: const HexPos(0, 0),
      zones: {
        ZoneName.ambient: ZoneAction(source: _app, mode: DisplayMode.overall),
        ZoneName.dots: ZoneAction(source: _app, mode: DisplayMode.history),
      },
    ),
    Tile(
      id: 'site',
      label: 'Site',
      kind: TileKind.project,
      chainIndex: 2,
      pos: const HexPos(1, 1),
      zones: {
        ZoneName.ambient: ZoneAction(source: _site, mode: DisplayMode.overall),
      },
    ),
  ],
);

List<Rgb> _at(LedFrame frame, List<int> indices) => [
  for (final i in indices) frame[i],
];

void main() {
  const renderer = FrameRenderer();
  final palette = Palette();
  final green = palette[Status.success];
  final red = palette[Status.failure];
  final blue = palette[Status.cancelled];
  final grey = palette[Status.unknown];
  final orange = palette[Status.running];

  group('états stables', () {
    late LedFrame frame;

    setUp(() {
      frame = renderer.render(_config(), {
        _app.key: const SourceState(
          history: [Status.success, Status.failure, Status.cancelled],
        ),
        _site.key: const SourceState(history: [Status.failure]),
      }, Duration.zero);
    });

    test('taille = 3 + 9·2', () {
      expect(frame.length, 21);
    });

    test('master : état global de sa source sur les 3 LED', () {
      expect(_at(frame, [0, 1, 2]), everyElement(red));
    });

    test('ambiance = run le plus récent, sur les LED 3, 4, 10, 11', () {
      expect(_at(frame, [3, 4, 10, 11]), everyElement(green));
    });

    test('historique : point n° 1 (LED 9) = run le plus récent, '
        'points sans run en gris', () {
      expect(_at(frame, [9, 8, 7, 6, 5]), [green, red, blue, grey, grey]);
    });

    test('zone sans action : éteinte', () {
      expect(_at(frame, [14, 15, 16, 17, 18]), everyElement(Rgb.black));
    });

    test('ambiance de la tuile n° 2 sur les LED 12, 13, 19, 20', () {
      expect(_at(frame, [12, 13, 19, 20]), everyElement(red));
    });
  });

  test('source pas encore lue : inconnu', () {
    final frame = renderer.render(_config(), const {}, Duration.zero);
    expect(_at(frame, [3, 4, 10, 11, 9, 8, 7, 6, 5]), everyElement(grey));
  });

  test('les zones de même source partagent un seul état', () {
    final sameSource = SourceConfig(
      type: 'github',
      settings: {'workflow': 'ci.yml', 'repo': ' acme/app '},
    );
    expect(sameSource.key, _app.key);
  });

  group('pulsation', () {
    final states = {
      _app.key: const SourceState(history: [Status.running, Status.success]),
    };

    test(
      'creux à t = 0, maximum à mi-période, creux à nouveau à 1 période',
      () {
        expect(renderer.pulseLevel(Duration.zero), closeTo(0.15, 1e-9));
        expect(
          renderer.pulseLevel(const Duration(seconds: 1)),
          closeTo(1, 1e-9),
        );
        expect(
          renderer.pulseLevel(const Duration(seconds: 2)),
          closeTo(0.15, 1e-9),
        );
      },
    );

    test('le run en cours pulse, les runs terminés restent fixes', () {
      final low = renderer.render(_config(), states, Duration.zero);
      final high = renderer.render(
        _config(),
        states,
        const Duration(seconds: 1),
      );
      final dim = orange.scaled(0.15);

      expect(_at(low, [3, 4, 10, 11, 9]), everyElement(dim));
      expect(_at(high, [3, 4, 10, 11, 9]), everyElement(orange));
      expect(low[8], green);
      expect(high[8], green);
    });

    test('« en file » pulse aussi', () {
      expect(
        renderer.colorFor(palette, (
          status: Status.queued,
          intensity: 1.0,
        ), Duration.zero),
        palette[Status.queued].scaled(0.15),
      );
    });
  });

  group('identifier', () {
    final states = {
      _app.key: const SourceState(history: [Status.success]),
    };

    test('la tuile clignote en blanc, les autres sont inchangées', () {
      final on = renderer.render(
        _config(),
        states,
        Duration.zero,
        identify: {'app'},
      );
      final off = renderer.render(
        _config(),
        states,
        const Duration(milliseconds: 300),
        identify: {'app'},
      );

      expect(
        _at(on, [for (var i = 3; i <= 11; i++) i]),
        everyElement(Rgb.white),
      );
      expect(
        _at(off, [for (var i = 3; i <= 11; i++) i]),
        everyElement(Rgb.black),
      );
      expect(_at(on, [12, 13, 19, 20]), everyElement(grey));
    });

    test('la master peut être identifiée', () {
      final frame = renderer.render(
        _config(),
        states,
        Duration.zero,
        identify: {'master'},
      );
      expect(_at(frame, [0, 1, 2]), everyElement(Rgb.white));
    });
  });

  test('une tuile au rang invalide est ignorée sans erreur', () {
    final config = Config(
      tiles: [
        Tile(
          id: 'stray',
          label: '',
          kind: TileKind.project,
          chainIndex: 0,
          pos: const HexPos(0, 0),
          zones: {
            ZoneName.ambient: ZoneAction(
              source: _app,
              mode: DisplayMode.overall,
            ),
          },
        ),
      ],
    );
    expect(renderer.render(config, const {}, Duration.zero).length, 3);
  });

  test('octets DDP dans l\'ordre R, G, B', () {
    final frame = LedFrame(2)..[1] = const Rgb(1, 2, 3);
    expect(frame.toRgbBytes(), [0, 0, 0, 1, 2, 3]);
  });
}
