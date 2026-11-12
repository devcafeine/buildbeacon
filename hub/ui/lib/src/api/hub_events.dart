// BuildBeacon UI — Live events from the Hub (Server-Sent Events).
// Version 1.1 (2026-11-12) — comments in English.

import 'dart:async';
import 'dart:convert';

import 'event_stream_io.dart'
    if (dart.library.js_interop) 'event_stream_web.dart'
    as platform;

/// What the interface receives on `/api/events`.
sealed class HubEvent {
  const HubEvent();
}

/// A named event (`config`, `state`) and its JSON data.
final class HubMessage extends HubEvent {
  const HubMessage(this.name, this.data);

  final String name;
  final String data;
}

/// Connection to the stream opened or lost (the stream reconnects by itself).
final class HubLinkChanged extends HubEvent {
  const HubLinkChanged({required this.open});

  final bool open;
}

/// Opens the event stream [url]; reconnects by itself.
typedef HubEventSource = Stream<HubEvent> Function(Uri url);

/// Browser: `EventSource`; elsewhere (tests, desktop): streaming HTTP
/// request.
Stream<HubEvent> openHubEvents(Uri url) => platform.openHubEvents(url);

/// Splits a `text/event-stream` stream into messages: `event:` and `data:`
/// fields, empty line = end of message, `:` = comment.
Stream<HubMessage> parseServerSentEvents(Stream<String> text) async* {
  String? name;
  final data = <String>[];
  await for (final line in text.transform(const LineSplitter())) {
    if (line.isEmpty) {
      if (data.isNotEmpty) yield HubMessage(name ?? 'message', data.join('\n'));
      name = null;
      data.clear();
      continue;
    }
    if (line.startsWith(':')) continue;
    final colon = line.indexOf(':');
    final field = colon < 0 ? line : line.substring(0, colon);
    var value = colon < 0 ? '' : line.substring(colon + 1);
    if (value.startsWith(' ')) value = value.substring(1);
    switch (field) {
      case 'event':
        name = value;
      case 'data':
        data.add(value);
    }
  }
}
