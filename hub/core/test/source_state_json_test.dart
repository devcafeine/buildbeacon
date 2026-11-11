// BuildBeacon Hub — Tests : état d'une source ↔ JSON.
// Version 1.0 (2026-11-11)

import 'package:buildbeacon_core/buildbeacon_core.dart';
import 'package:test/test.dart';

void main() {
  test('aller-retour complet', () {
    final state = SourceState(
      status: Status.running,
      history: const [Status.running, Status.success, Status.failure],
      metrics: const {
        'progress': Metric(42, unit: '%', min: 0, max: 100),
        'nozzle_temp': Metric(215.5),
      },
      error: const LocalizedText({'en': 'Timeout', 'fr': 'Délai dépassé'}),
      updatedAt: DateTime.utc(2026, 11, 11, 21, 55, 46),
    );
    final json = SourceStateJson.encode(state);
    expect(json['status'], 'running');
    expect(json['metrics'], {
      'progress': {'value': 42.0, 'unit': '%', 'min': 0.0, 'max': 100.0},
      'nozzle_temp': {'value': 215.5},
    });
    expect(json['updated_at'], '2026-11-11T21:55:46.000Z');

    final back = SourceStateJson.decode(json);
    expect(back.status, Status.running);
    expect(back.history, state.history);
    expect(back.metric('progress')!.value, 42);
    expect(back.metric('progress')!.unit, '%');
    expect(back.metric('progress')!.max, 100);
    expect(back.metric('nozzle_temp')!.min, isNull);
    expect(back.error!.resolve('fr'), 'Délai dépassé');
    expect(back.updatedAt, state.updatedAt);
    expect(SourceStateJson.encode(back), json);
  });

  test('état jamais lu', () {
    final json = SourceStateJson.encode(SourceState.unknown);
    expect(json, {
      'status': 'unknown',
      'history': <Object?>[],
      'metrics': <String, Object?>{},
      'error': null,
      'updated_at': null,
    });
    expect(SourceStateJson.decode(json).status, Status.unknown);
  });

  test('lecture tolérante : valeurs inconnues ou mal formées ignorées', () {
    final state = SourceStateJson.decode({
      'status': 'exploded',
      'history': ['success', 'later', 3],
      'metrics': {
        'ok': {'value': 1},
        'no_value': {'unit': '%'},
        'not_object': 5,
      },
      'error': 'texte brut',
      'updated_at': 'hier',
    });
    expect(state.status, Status.unknown);
    expect(state.history, [Status.success, Status.unknown, Status.unknown]);
    expect(state.metrics.keys, ['ok']);
    expect(state.error, isNull);
    expect(state.updatedAt, isNull);

    expect(
      SourceStateJson.decode({'history': 'x', 'metrics': []}).history,
      isEmpty,
    );
  });
}
