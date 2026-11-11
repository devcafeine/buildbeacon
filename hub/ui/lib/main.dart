// BuildBeacon UI — Point d'entrée de l'interface web, servie par le Hub.
// Version 1.0 (2026-11-11)

import 'package:flutter/material.dart';

import 'src/api/hub_api.dart';
import 'src/app.dart';

void main() {
  // L'API est servie par le même Hub que la page : <adresse de la page>/api/…
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
