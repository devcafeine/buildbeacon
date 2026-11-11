// BuildBeacon Hub — Tests : API JSON de WLED (informations, luminosité).
// Version 1.0 (2026-11-11)

import 'dart:convert';

import 'package:buildbeacon_hub/buildbeacon_hub.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  test('informations : version, nom, nombre de LED', () async {
    final client = MockClient((request) async {
      // Port 80 par défaut : absent de l'URL.
      expect(request.url.toString(), 'http://buildbeacon.local/json/info');
      return http.Response(
        jsonEncode({
          'ver': '0.15.0',
          'name': 'BuildBeacon',
          'leds': {'count': 21, 'pwr': 120},
        }),
        200,
      );
    });
    final info = await WledClient(
      host: 'buildbeacon.local',
      client: client,
    ).info();
    expect(info, (version: '0.15.0', name: 'BuildBeacon', ledCount: 21));
  });

  test('réponse qui n\'est pas l\'API de WLED : erreur', () {
    final client = MockClient((_) async => http.Response('<html>', 200));
    expect(WledClient(host: 'x', client: client).info(), throwsA(anything));
    final notFound = MockClient((_) async => http.Response('', 404));
    expect(
      WledClient(host: 'x', client: notFound).info(),
      throwsA(isA<WledException>()),
    );
  });

  test('luminosité : POST /json/state {"bri": …}', () async {
    late http.Request sent;
    final client = MockClient((request) async {
      sent = request;
      return http.Response('{"success":true}', 200);
    });
    await WledClient(
      host: '192.168.1.50',
      port: 8080,
      client: client,
    ).setBrightness(128);

    expect(sent.method, 'POST');
    expect(sent.url.toString(), 'http://192.168.1.50:8080/json/state');
    expect(jsonDecode(sent.body), {'bri': 128});
  });
}
