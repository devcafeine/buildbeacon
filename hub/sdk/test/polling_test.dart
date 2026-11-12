// BuildBeacon Hub — SDK tests: polling stream.
// Version 1.3 (2026-11-12) — test names in English.

import 'package:buildbeacon_plugin_sdk/buildbeacon_plugin_sdk.dart';
import 'package:test/test.dart';

void main() {
  const tick = Duration(milliseconds: 1);

  test(
    'reads immediately then at each interval, with the previous state',
    () async {
      final seen = <int>[];
      final states = await pollingStream(tick, (previous) async {
        seen.add(previous.history.length);
        return SourceState(history: [...previous.history, Status.success]);
      }).take(3).toList();

      expect(states.map((s) => s.history.length), [1, 2, 3]);
      expect(seen, [0, 1, 2]);
    },
  );

  test('an error keeps the last known values', () async {
    var reads = 0;
    final states = await pollingStream(tick, (previous) async {
      reads++;
      if (reads == 2) {
        throw const SourceException(
          LocalizedText({
            'en': 'repository not found',
            'fr': 'dépôt introuvable',
          }),
        );
      }
      if (reads == 3) throw StateError('boom');
      return const SourceState(history: [Status.failure]);
    }).take(4).toList();

    expect(states[0].error, isNull);
    expect(states[1].history, [Status.failure]);
    expect(states[1].error?.resolve('fr'), 'dépôt introuvable');
    expect(states[1].error?.resolve('en'), 'repository not found');
    expect(states[2].error?.resolve('fr'), contains('erreur inattendue'));
    expect(states[3].error, isNull);
  });

  test('no more reads after cancellation', () async {
    var reads = 0;
    await pollingStream(tick, (previous) async {
      reads++;
      return previous;
    }).first;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(reads, 1);
  });
}
