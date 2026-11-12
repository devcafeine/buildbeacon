// BuildBeacon Hub — Simulator: follows config.json, so that the layout matches the Hub's configuration.
// Version 1.0 (2026-11-12)

import 'dart:async';
import 'dart:io';

import 'package:buildbeacon_core/buildbeacon_core.dart';

import '../config_file.dart';

/// Follows the configuration file [path]: emits it right away (`null` while
/// the file does not exist), then on every change, checked every [interval].
///
/// A file that cannot be read or is rejected (being edited by hand, for
/// example) is reported through [log] and skipped: the last good
/// configuration stays. A file that disappears keeps it too.
///
/// The file is small (a few KB): reading it every second is simpler and more
/// robust than watching its folder, which may not exist yet (the Hub creates
/// the file on its first start), and some editors replace the file instead of
/// writing it.
Stream<Config?> followConfigFile(
  String path, {
  Duration interval = const Duration(seconds: 1),
  void Function(LocalizedText message)? log,
}) {
  late final StreamController<Config?> controller;
  Timer? timer;
  String? lastText;
  var first = true;
  var busy = false;

  Future<void> check() async {
    if (busy || controller.isClosed) return;
    busy = true;
    try {
      final file = File(path);
      final String text;
      try {
        // '' = no file.
        text = await file.exists() ? await file.readAsString() : '';
      } on FileSystemException {
        return; // being replaced: next time
      }
      if (text == lastText) return;
      lastText = text;
      if (text.isEmpty) {
        if (first) {
          controller.add(null);
          log?.call(
            LocalizedText.build(
              (l) => tr(
                l,
                en:
                    '$path not found yet: default layout until the Hub '
                    'creates it.',
                fr:
                    '$path introuvable pour l\'instant : disposition par '
                    'défaut en attendant que le Hub le crée.',
              ),
            ),
          );
        }
        return;
      }
      try {
        final config = parseConfigText(path, text);
        controller.add(config);
        final tiles = config.tiles.length;
        log?.call(
          LocalizedText.build(
            (l) => tr(
              l,
              en: 'Layout from $path: $tiles tiles.',
              fr: 'Disposition lue dans $path : $tiles tuiles.',
            ),
          ),
        );
      } on LocalizedFormatException catch (e) {
        if (first) controller.add(null);
        log?.call(
          LocalizedText.build(
            (l) => tr(
              l,
              en: '${e.text.resolve(l)}; previous layout kept.',
              fr: '${e.text.resolve(l)} ; disposition précédente gardée.',
            ),
          ),
        );
      }
    } finally {
      first = false;
      busy = false;
    }
  }

  controller = StreamController<Config?>(
    onListen: () {
      unawaited(check());
      timer = Timer.periodic(interval, (_) => unawaited(check()));
    },
    onCancel: () => timer?.cancel(),
  );
  return controller.stream;
}
