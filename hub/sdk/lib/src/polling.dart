// BuildBeacon Hub — Plugin SDK: polling stream.
// Version 1.2 (2026-11-12) — comments in English.

import 'dart:async';

import 'localized_text.dart';
import 'source_plugin.dart';
import 'source_state.dart';

/// Polling stream: reads as soon as it is listened to, then [interval] after
/// each read completes. No more reads once the stream is cancelled.
///
/// [read] receives the previous state (useful for an ETag cache). An error
/// becomes [SourceState.error] while keeping the last known values: the
/// panel keeps showing the last valid state. Throwing a [SourceException]
/// gives the user a translated message.
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
