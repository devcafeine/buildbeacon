// BuildBeacon Hub — Tests : indicateurs chiffrés (modes thresholds et gauge).
// Version 1.2 (2026-11-11) — identifiants en anglais (thresholds, gauge, warning, failure, above, below), messages traduits.

import 'dart:convert';

import 'package:buildbeacon_core/buildbeacon_core.dart';
import 'package:test/test.dart';

// Sans registre de plugins, le cœur ne vérifie pas le type de source :
// seul l'état en cache compte pour le calcul.
final _source = SourceConfig(type: 'printer', settings: {'name': 'workshop'});

/// Imprimante 3D en cours d'impression
/// (Bambu Lab : gcode_state RUNNING, mc_percent 62, buse à 220 °C).
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
  group('seuils', () {
    test('alerte au-dessus (température de buse)', () {
      const t = Thresholds(warning: 240, failure: 260);
      expect([220, 240, 259, 260, 300].map(t.evaluate), [
        Status.success,
        Status.warning,
        Status.warning,
        Status.failure,
        Status.failure,
      ]);
    });

    test('alerte en dessous (filament restant, ventes du jour)', () {
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

    test('un seul seuil suffit', () {
      const t = Thresholds(failure: 100);
      expect([99, 100].map(t.evaluate), [Status.success, Status.failure]);
    });

    test('mode thresholds : toute la zone prend la couleur de la mesure', () {
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

    test('sans « metric » : la première mesure de la source', () {
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

    test('mesure absente ou source pas encore lue : inconnu', () {
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

  group('jauge', () {
    test('62 % sur 5 LED : 3 pleines, la 4e à 10 %, la 5e éteinte', () {
      final leds = FrameRenderer.zoneOutputs(
        _action(DisplayMode.gauge, metric: 'progress'),
        _printing,
        5,
      );
      expect(_intensities(leds), _closeToAll([1, 1, 1, 0.1, 0]));
    });

    test('couleur = état de la source (impression en cours → pulse)', () {
      final leds = FrameRenderer.zoneOutputs(
        _action(DisplayMode.gauge, metric: 'progress'),
        _printing,
        5,
      );
      expect(_statuses(leds), everyElement(Status.running));
    });

    test('avec des seuils, la couleur suit la valeur', () {
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

    test('les bornes de l\'action priment sur celles de la source', () {
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

    test('sans bornes : 0 – 100', () {
      const state = SourceState(metrics: {'x': Metric(40)});
      final leds = FrameRenderer.zoneOutputs(
        _action(DisplayMode.gauge),
        state,
        5,
      );
      expect(_intensities(leds), _closeToAll([1, 1, 0, 0, 0]));
    });

    test('valeur hors bornes : ramenée dans la jauge', () {
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

    test('mesure absente : toute la zone en gris inconnu', () {
      final leds = FrameRenderer.zoneOutputs(
        _action(DisplayMode.gauge, metric: 'progress'),
        SourceState.unknown,
        5,
      );
      expect(leds, everyElement((status: Status.unknown, intensity: 1.0)));
    });

    test('rendu : LED partielle atténuée, LED vide éteinte', () {
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
      // Mi-période : la pulsation est à son maximum.
      final frame = renderer.render(config, {
        _source.key: _printing,
      }, const Duration(seconds: 1));

      // Points n° 1 → 5 = LED 9, 8, 7, 6, 5.
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

    test('seuils dans le mauvais ordre', () {
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

    test('mode thresholds sans seuil', () {
      expect(issues('ambient', {'mode': 'thresholds'}), [
        'Tuile « Bambu » : ambiance : le mode seuils demande au moins un '
            'seuil (warning ou failure)',
      ]);
    });

    test('pas de jauge sur l\'ambiance (LED non contiguës)', () {
      expect(issues('ambient', {'mode': 'gauge'}), [
        contains('mode « jauge » impossible dans la zone ambiance'),
      ]);
    });

    test('jauge : max ≤ min', () {
      expect(
        issues('dots', {
          'mode': 'gauge',
          'options': {'min': 10, 'max': 10},
        }),
        [contains('max (10) doit être supérieur à min (10)')],
      );
    });

    test('direction de seuil inconnue : erreur de format', () {
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

  test('aller-retour JSON des options', () {
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
