// BuildBeacon Hub — Tests: LED frame computation.
// Version 1.5 (2026-11-12) — test names in English.

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

/// The user's layout: master tile at (0, 1), tiles at (0, 0) and (1, 1).
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

  group('steady states', () {
    late LedFrame frame;

    setUp(() {
      frame = renderer.render(_config(), {
        _app.key: const SourceState(
          history: [Status.success, Status.failure, Status.cancelled],
        ),
        _site.key: const SourceState(history: [Status.failure]),
      }, Duration.zero);
    });

    test('size = 3 + 9·2', () {
      expect(frame.length, 21);
    });

    test('master: overall status of its source on all 3 LEDs', () {
      expect(_at(frame, [0, 1, 2]), everyElement(red));
    });

    test('ambient = most recent run, on LEDs 3, 4, 10, 11', () {
      expect(_at(frame, [3, 4, 10, 11]), everyElement(green));
    });

    test('history: dot no. 1 (LED 9) = most recent run, '
        'dots without a run in grey', () {
      expect(_at(frame, [9, 8, 7, 6, 5]), [green, red, blue, grey, grey]);
    });

    test('zone without an action: off', () {
      expect(_at(frame, [14, 15, 16, 17, 18]), everyElement(Rgb.black));
    });

    test('ambient zone of tile no. 2 on LEDs 12, 13, 19, 20', () {
      expect(_at(frame, [12, 13, 19, 20]), everyElement(red));
    });
  });

  test('source not read yet: unknown', () {
    final frame = renderer.render(_config(), const {}, Duration.zero);
    expect(_at(frame, [3, 4, 10, 11, 9, 8, 7, 6, 5]), everyElement(grey));
  });

  test('zones with the same source share a single state', () {
    final sameSource = SourceConfig(
      type: 'github',
      settings: {'workflow': 'ci.yml', 'repo': ' acme/app '},
    );
    expect(sameSource.key, _app.key);
  });

  group('pulse', () {
    final states = {
      _app.key: const SourceState(history: [Status.running, Status.success]),
    };

    test('trough at t = 0, peak at half period, trough again at 1 period', () {
      expect(renderer.pulseLevel(Duration.zero), closeTo(0.15, 1e-9));
      expect(renderer.pulseLevel(const Duration(seconds: 1)), closeTo(1, 1e-9));
      expect(
        renderer.pulseLevel(const Duration(seconds: 2)),
        closeTo(0.15, 1e-9),
      );
    });

    test('the in-progress run pulses, completed runs stay steady', () {
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

    test('"queued" pulses too', () {
      expect(
        renderer.colorFor(palette, (
          status: Status.queued,
          intensity: 1.0,
        ), Duration.zero),
        palette[Status.queued].scaled(0.15),
      );
    });
  });

  group('identify', () {
    final states = {
      _app.key: const SourceState(history: [Status.success]),
    };

    test('the tile blinks white, the others are unchanged', () {
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

    test('the master tile can be identified', () {
      final frame = renderer.render(
        _config(),
        states,
        Duration.zero,
        identify: {'master'},
      );
      expect(_at(frame, [0, 1, 2]), everyElement(Rgb.white));
    });
  });

  test('a tile at an invalid chain position is ignored without error', () {
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

  test('DDP bytes in R, G, B order', () {
    final frame = LedFrame(2)..[1] = const Rgb(1, 2, 3);
    expect(frame.toRgbBytes(), [0, 0, 0, 1, 2, 3]);
  });
}
