// BuildBeacon UI — Événements en direct du Hub (Server-Sent Events).
// Version 1.0 (2026-11-11)

import 'dart:async';
import 'dart:convert';

import 'event_stream_io.dart'
    if (dart.library.js_interop) 'event_stream_web.dart'
    as platform;

/// Ce que reçoit l'interface sur `/api/events`.
sealed class HubEvent {
  const HubEvent();
}

/// Un événement nommé (`config`, `state`) et ses données JSON.
final class HubMessage extends HubEvent {
  const HubMessage(this.name, this.data);

  final String name;
  final String data;
}

/// Connexion au flux ouverte ou perdue (le flux se reconnecte seul).
final class HubLinkChanged extends HubEvent {
  const HubLinkChanged({required this.open});

  final bool open;
}

/// Ouvre le flux d'événements [url] ; se reconnecte seul.
typedef HubEventSource = Stream<HubEvent> Function(Uri url);

/// Navigateur : `EventSource` ; ailleurs (tests, bureau) : requête HTTP en
/// continu.
Stream<HubEvent> openHubEvents(Uri url) => platform.openHubEvents(url);

/// Découpe un flux `text/event-stream` en messages : champs `event:` et
/// `data:`, ligne vide = fin du message, `:` = commentaire.
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
