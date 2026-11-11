// BuildBeacon UI — Flux d'événements dans le navigateur : EventSource.
// Version 1.0 (2026-11-11)

import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'hub_events.dart';

/// `EventSource` se reconnecte seul ; `onerror` signale chaque coupure.
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
