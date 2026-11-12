// BuildBeacon UI — Entry point of the web interface, served by the Hub.
// Version 1.1 (2026-11-12) — comments in English.

import 'package:flutter/material.dart';

import 'src/api/hub_api.dart';
import 'src/app.dart';

void main() {
  // The API is served by the same Hub as the page: <page address>/api/…
  final page = Uri.base;
  runApp(
    BuildBeaconApp(
      api: HubApi(
        base: page.replace(query: '', fragment: ''),
      ),
      initialLanguage: page.queryParameters['lang'],
    ),
  );
}
