// BuildBeacon UI — Event stream outside the browser (tests, desktop): streaming HTTP.
// Version 1.1 (2026-11-12) — comments in English.

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'hub_events.dart';

/// Reads `text/event-stream` through an HTTP request; when the connection
/// drops, reports the lost connection and retries every 3 s.
Stream<HubEvent> openHubEvents(Uri url) {
  late final StreamController<HubEvent> controller;
  var closed = false;
  http.Client? client;

  Future<void> run() async {
    while (!closed) {
      final current = client = http.Client();
      try {
        final request = http.Request('GET', url)
          ..headers['accept'] = 'text/event-stream';
        final response = await current.send(request);
        if (response.statusCode == 200) {
          controller.add(const HubLinkChanged(open: true));
          final messages = parseServerSentEvents(
            response.stream.transform(utf8.decoder),
          );
          await for (final message in messages) {
            if (closed) break;
            controller.add(message);
          }
        }
      } on Object {
        // Hub unreachable: retried below.
      } finally {
        current.close();
      }
      if (closed) break;
      controller.add(const HubLinkChanged(open: false));
      await Future<void>.delayed(const Duration(seconds: 3));
    }
  }

  controller = StreamController<HubEvent>(
    onListen: () => unawaited(run()),
    onCancel: () {
      closed = true;
      client?.close();
    },
  );
  return controller.stream;
}
