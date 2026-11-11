// BuildBeacon Hub — API JSON de WLED : vérification de la connexion et luminosité.
// Version 1.0 (2026-11-11)

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Ce que le Hub retient de `/json/info`.
typedef WledInfo = ({String version, String name, int ledCount});

/// Erreur de l'API JSON de WLED (message technique, en anglais).
final class WledException implements Exception {
  const WledException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Petit client de l'API JSON de WLED, limité à ce dont le Hub a besoin :
/// vérifier la connexion, lire le nombre de LED, régler la luminosité. Les
/// couleurs, elles, passent par DDP.
final class WledClient {
  WledClient({
    required this.host,
    this.port = 80,
    required http.Client client,
    this.timeout = const Duration(seconds: 3),
  }) : _client = client;

  final String host;
  final int port;
  final Duration timeout;
  final http.Client _client;

  Uri _uri(String path) =>
      Uri(scheme: 'http', host: host, port: port, path: path);

  /// Version, nom et nombre de LED. Lève une [WledException] (ou une erreur
  /// réseau) si WLED ne répond pas comme son API.
  Future<WledInfo> info() async {
    final response = await _client.get(_uri('/json/info')).timeout(timeout);
    if (response.statusCode != 200) {
      throw WledException('HTTP ${response.statusCode} on /json/info');
    }
    final json = jsonDecode(response.body);
    if (json case {'leds': {'count': final int count}}) {
      return (
        version: switch (json) {
          {'ver': final String version} => version,
          _ => '?',
        },
        name: switch (json) {
          {'name': final String name} => name,
          _ => 'WLED',
        },
        ledCount: count,
      );
    }
    throw const WledException('unexpected /json/info answer');
  }

  /// Règle la luminosité globale (0 – 255).
  Future<void> setBrightness(int brightness) async {
    final response = await _client
        .post(
          _uri('/json/state'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'bri': brightness}),
        )
        .timeout(timeout);
    if (response.statusCode != 200) {
      throw WledException('HTTP ${response.statusCode} on /json/state');
    }
  }
}
