// BuildBeacon Hub — Tests: GitHub status/conclusion → display status.
// Version 1.6 (2026-11-12) — test names in English.

import 'package:buildbeacon_plugin_github/buildbeacon_plugin_github.dart';
import 'package:buildbeacon_plugin_sdk/buildbeacon_plugin_sdk.dart';
import 'package:test/test.dart';

void main() {
  const cases = <(String?, String?, Status)>[
    ('completed', 'success', Status.success),
    ('completed', 'neutral', Status.success),
    ('completed', 'failure', Status.failure),
    ('completed', 'timed_out', Status.failure),
    ('completed', 'startup_failure', Status.failure),
    ('completed', 'action_required', Status.failure),
    ('completed', 'cancelled', Status.cancelled),
    ('completed', 'skipped', Status.unknown),
    ('completed', 'stale', Status.unknown),
    ('completed', null, Status.unknown),
    ('in_progress', null, Status.running),
    ('queued', null, Status.queued),
    ('waiting', null, Status.queued),
    ('requested', null, Status.queued),
    ('pending', null, Status.queued),
    (null, null, Status.unknown),
    ('future_status', null, Status.unknown),
  ];

  for (final (status, conclusion, expected) in cases) {
    test('$status / $conclusion → ${expected.json}', () {
      expect(
        statusFromGithub(status: status, conclusion: conclusion),
        expected,
      );
    });
  }

  test('conclusion is ignored until the run is completed', () {
    expect(
      statusFromGithub(status: 'in_progress', conclusion: 'failure'),
      Status.running,
    );
  });
}
