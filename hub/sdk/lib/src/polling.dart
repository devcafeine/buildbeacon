// BuildBeacon Hub — SDK des plugins : flux de scrutation.
// Version 1.1 (2026-11-11) — messages d'erreur traduits.

import 'dart:async';

import 'localized_text.dart';
import 'source_plugin.dart';
import 'source_state.dart';

/// Flux de scrutation : lit dès l'abonnement, puis [interval] après la fin
/// de chaque lecture. Plus aucune lecture une fois le flux annulé.
///
/// [read] reçoit l'état précédent (utile pour un cache ETag). Une erreur
/// devient [SourceState.error] en gardant les dernières valeurs connues : le
/// panneau continue d'afficher le dernier état valable. Lever une
/// [SourceException] donne un message traduit à l'utilisateur.
Stream<SourceState> pollingStream(
  Duration interval,
  Future<SourceState> Function(SourceState previous) read,
) {
  late final StreamController<SourceState> controller;
  var state = SourceState.unknown;
  var active = true;
  Timer? timer;

  Future<void> tick() async {
    try {
      state = await read(state);
    } on SourceException catch (e) {
      state = state.withError(e.message);
    } catch (e) {
      state = state.withError(
        LocalizedText.build(
          (l) =>
              tr(l, en: 'unexpected error: $e', fr: 'erreur inattendue : $e'),
        ),
      );
    }
    if (!active) return;
    controller.add(state);
    timer = Timer(interval, () => unawaited(tick()));
  }

  controller = StreamController<SourceState>(
    onListen: () => unawaited(tick()),
    onCancel: () {
      active = false;
      timer?.cancel();
    },
  );
  return controller.stream;
}
