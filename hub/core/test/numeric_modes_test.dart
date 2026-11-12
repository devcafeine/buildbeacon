// BuildBeacon Hub — Tests: numeric indicators (thresholds and gauge modes).
// Version 1.4 (2026-11-12) — test names in English.

import 'dart:convert';

import 'package:buildbeacon_core/buildbeacon_core.dart';
import 'package:test/test.dart';

// Without a plugin registry, the core does not check the source type: only
// the cached state matters for the computation.
final _source = SourceConfig(type: 'printer', settings: {'name': 'workshop'});

/// 3D printer in the middle of a print
/// (Bambu Lab: gcode_state RUNNING, mc_percent 62, nozzle at 220 °C).
const _printing = SourceState(
  status: Status.running,
  metrics: {
    'progress': Metric(62, unit: '%', min: 0, max: 100),
    'nozzle_temp': Metric(220, unit: '°C'),
  },
);

ZoneAction _action(
  DisplayMode mode, {
  String? metric,
  Thresholds thresholds = Thresholds.none,
  num? min,
  num? max,
}) => ZoneAction(
  source: _source,
  mode: mode,
  metric: metric,
  thresholds: thresholds,
  min: min,
  max: max,
);

List<Status> _statuses(List<LedOutput> leds) => [
  for (final led in leds) led.status,
];

List<double> _intensities(List<LedOutput> leds) => [
  for (final led in leds) led.intensity,
];

Matcher _closeToAll(List<double> expected) => pairwiseCompare<double, double>(
  expected,
  (e, actual) => (e - actual).abs() < 1e-9,
  'proche de',
);

void main() {
  group('thresholds', () {
    test('alert above (nozzle temperature)', () {
      const t = Thresholds(warning: 240, failure: 260);
      expect([220, 240, 259, 260, 300].map(t.evaluate), [
        Status.success,
        Status.warning,
        Status.warning,
        Status.failure,
        Status.failure,
      ]);
    });

    test('alert below (remaining filament, daily sales)', () {
      const t = Thresholds(
        warning: 200,
        failure: 50,
        direction: AlertDirection.below,
      );
      expect([500, 200, 51, 50, 0].map(t.evaluate), [
        Status.success,
        Status.warning,
        Status.warning,
        Status.failure,
        Status.failure,
      ]);
    });

    test('a single threshold is enough', () {
      const t = Thresholds(failure: 100);
      expect([99, 100].map(t.evaluate), [Status.success, Status.failure]);
    });

    test('thresholds mode: the whole zone takes the metric color', () {
      final leds = FrameRenderer.zoneOutputs(
        _action(
          DisplayMode.thresholds,
          metric: 'nozzle_temp',
          thresholds: const Thresholds(warning: 210, failure: 260),
        ),
        _printing,
        4,
      );
      expect(leds, everyElement((status: Status.warning, intensity: 1.0)));
    });

    test('without "metric": first metric of the source', () {
      final leds = FrameRenderer.zoneOutputs(
        _action(
          DisplayMode.thresholds,
          thresholds: const Thresholds(failure: 50),
        ),
        _printing,
        3,
      );
      expect(_statuses(leds), everyElement(Status.failure));
    });

    test('missing metric or source not read yet: unknown', () {
      final action = _action(
        DisplayMode.thresholds,
        metric: 'humidity',
        thresholds: const Thresholds(failure: 1),
      );
      for (final state in [_printing, SourceState.unknown]) {
        expect(
          _statuses(FrameRenderer.zoneOutputs(action, state, 4)),
          everyElement(Status.unknown),
        );
      }
    });
  });

  group('gauge', () {
    test('62% on 5 LEDs: 3 full, 4th at 10%, 5th off', () {
      final leds = FrameRenderer.zoneOutputs(
        _action(DisplayMode.gauge, metric: 'progress'),
        _printing,
        5,
      );
      expect(_intensities(leds), _closeToAll([1, 1, 1, 0.1, 0]));
    });

    test('color = source status (print running → pulses)', () {
      final leds = FrameRenderer.zoneOutputs(
        _action(DisplayMode.gauge, metric: 'progress'),
        _printing,
        5,
      );
      expect(_statuses(leds), everyElement(Status.running));
    });

    test('with thresholds, color follows the value', () {
      final leds = FrameRenderer.zoneOutputs(
        _action(
          DisplayMode.gauge,
          metric: 'nozzle_temp',
          thresholds: const Thresholds(warning: 240, failure: 260),
          max: 300,
        ),
        _printing,
        5,
      );
      expect(_statuses(leds), everyElement(Status.success));
    });

    test('action bounds take precedence over source bounds', () {
      const state = SourceState(
        status: Status.success,
        metrics: {'sales': Metric(25, min: 0, max: 100)},
      );
      final leds = FrameRenderer.zoneOutputs(
        _action(DisplayMode.gauge, max: 50),
        state,
        5,
      );
      expect(_intensities(leds), _closeToAll([1, 1, 0.5, 0, 0]));
    });

    test('without bounds: 0 – 100', () {
      const state = SourceState(metrics: {'x': Metric(40)});
      final leds = FrameRenderer.zoneOutputs(
        _action(DisplayMode.gauge),
        state,
        5,
      );
      expect(_intensities(leds), _closeToAll([1, 1, 0, 0, 0]));
    });

    test('out-of-bounds value: clamped to the gauge', () {
      for (final (value, expected) in [(150.0, 1.0), (-5.0, 0.0)]) {
        final state = SourceState(metrics: {'x': Metric(value)});
        final leds = FrameRenderer.zoneOutputs(
          _action(DisplayMode.gauge),
          state,
          5,
        );
        expect(_intensities(leds), everyElement(expected));
      }
    });

    test('missing metric: whole zone in unknown grey', () {
      final leds = FrameRenderer.zoneOutputs(
        _action(DisplayMode.gauge, metric: 'progress'),
        SourceState.unknown,
        5,
      );
      expect(leds, everyElement((status: Status.unknown, intensity: 1.0)));
    });

    test('rendering: partial LED dimmed, empty LED off', () {
      final config = Config(
        tiles: [
          Tile(
            id: 'printer',
            label: 'Bambu',
            kind: TileKind.project,
            chainIndex: 1,
            pos: const HexPos(0, 0),
            zones: {
              ZoneName.dots: _action(DisplayMode.gauge, metric: 'progress'),
            },
          ),
        ],
      );
      const renderer = FrameRenderer();
      final orange = Palette()[Status.running];
      // Half period: the pulse is at its maximum.
      final frame = renderer.render(config, {
        _source.key: _printing,
      }, const Duration(seconds: 1));

      // Dots #1 → 5 = LEDs 9, 8, 7, 6, 5.
      expect([frame[9], frame[8], frame[7]], everyElement(orange));
      expect(frame[6], orange.scaled(0.1));
      expect(frame[5], Rgb.black);
    });
  });

  group('validation', () {
    List<String> issues(String zone, Map<String, Object?> action) =>
        Config.fromJson({
          'tiles': [
            {
              'id': 'master',
              'kind': 'master',
              'chain_index': 0,
              'pos': {'q': 9, 'r': 9},
            },
            {
              'id': 'p',
              'label': 'Bambu',
              'kind': 'project',
              'chain_index': 1,
              'pos': {'q': 0, 'r': 0},
              'zones': {
                zone: {
                  'source': {'type': 'printer', 'name': 'workshop'},
                  ...action,
                },
              },
            },
          ],
        }).validate().resolveAll('fr');

    test('thresholds in the wrong order', () {
      expect(
        issues('dots', {
          'mode': 'thresholds',
          'options': {
            'thresholds': {'warning': 260, 'failure': 240},
          },
        }),
        [contains('au-dessus du seuil d\'échec')],
      );
    });

    test('thresholds mode without a threshold', () {
      expect(issues('ambient', {'mode': 'thresholds'}), [
        'Tuile « Bambu » : ambiance : le mode seuils demande au moins un '
            'seuil (warning ou failure)',
      ]);
    });

    test('no gauge on the ambient zone (non-contiguous LEDs)', () {
      expect(issues('ambient', {'mode': 'gauge'}), [
        contains('mode « jauge » impossible dans la zone ambiance'),
      ]);
    });

    test('gauge: max ≤ min', () {
      expect(
        issues('dots', {
          'mode': 'gauge',
          'options': {'min': 10, 'max': 10},
        }),
        [contains('max (10) doit être supérieur à min (10)')],
      );
    });

    test('unknown threshold direction: format error', () {
      expect(
        () => issues('dots', {
          'mode': 'thresholds',
          'options': {
            'thresholds': {'failure': 1, 'direction': 'sideways'},
          },
        }),
        throwsFormatException,
      );
    });
  });

  test('JSON round trip of options', () {
    final json = {
      'source': {'type': 'printer', 'name': 'workshop'},
      'mode': 'gauge',
      'options': {
        'metric': 'filament',
        'thresholds': {'warning': 200, 'failure': 50, 'direction': 'below'},
        'min': 0,
        'max': 1000,
      },
    };
    final action = ZoneAction.fromJson(json);
    expect(action.thresholds.direction, AlertDirection.below);
    expect(jsonDecode(jsonEncode(action.toJson())), json);
  });
}
