// BuildBeacon UI — Event stream in the browser: EventSource.
// Version 1.1 (2026-11-12) — comments in English.

import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'hub_events.dart';

/// `EventSource` reconnects by itself; `onerror` reports each disconnection.
Stream<HubEvent> openHubEvents(Uri url) {
  late final StreamController<HubEvent> controller;
  web.EventSource? source;

  void listen(String name) {
    source!.addEventListener(
      name,
      (web.MessageEvent event) {
        final data = event.data.dartify();
        if (data is String) controller.add(HubMessage(name, data));
      }.toJS,
    );
  }

  controller = StreamController<HubEvent>(
    onListen: () {
      final events = source = web.EventSource(url.toString());
      events.onopen = (web.Event _) {
        controller.add(const HubLinkChanged(open: true));
      }.toJS;
      events.onerror = (web.Event _) {
        controller.add(const HubLinkChanged(open: false));
      }.toJS;
      listen('config');
      listen('state');
    },
    onCancel: () => source?.close(),
  );
  return controller.stream;
}
