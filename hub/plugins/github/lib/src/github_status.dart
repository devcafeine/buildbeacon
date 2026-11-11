// BuildBeacon Hub — Correspondance status/conclusion GitHub → état d'affichage.
// Version 1.4 (2026-11-11) — états en anglais (success, failure…).

import 'package:buildbeacon_plugin_sdk/buildbeacon_plugin_sdk.dart';

/// Traduit les champs `status` et `conclusion` d'un workflow run GitHub.
///
/// Choix pour les conclusions sans couleur prévue dans la spec :
/// - `neutral` → succès (rien à corriger) ;
/// - `timed_out`, `startup_failure`, `action_required` → échec (il faut
///   intervenir) ;
/// - `skipped`, `stale` → inconnu (le run n'a rien prouvé).
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
