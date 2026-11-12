// BuildBeacon Hub — Mapping of GitHub status/conclusion → display status.
// Version 1.5 (2026-11-12) — comments in English.

import 'package:buildbeacon_plugin_sdk/buildbeacon_plugin_sdk.dart';

/// Maps the `status` and `conclusion` fields of a GitHub workflow run.
///
/// Choices for the conclusions that have no color in the spec:
/// - `neutral` → success (nothing to fix);
/// - `timed_out`, `startup_failure`, `action_required` → failure (someone
///   has to step in);
/// - `skipped`, `stale` → unknown (the run proved nothing).
Status statusFromGithub({required String? status, String? conclusion}) =>
    switch (status) {
      'completed' => switch (conclusion) {
        'success' || 'neutral' => Status.success,
        'failure' ||
        'timed_out' ||
        'startup_failure' ||
        'action_required' => Status.failure,
        'cancelled' => Status.cancelled,
        _ => Status.unknown,
      },
      'in_progress' => Status.running,
      'queued' || 'waiting' || 'requested' || 'pending' => Status.queued,
      _ => Status.unknown,
    };
