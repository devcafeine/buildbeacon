// BuildBeacon Hub — WLED JSON API: connection check and brightness.
// Version 1.1 (2026-11-12) — comments in English.

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// What the Hub keeps from `/json/info`.
typedef WledInfo = ({String version, String name, int ledCount});

/// Error from the WLED JSON API (technical message, in English).
final class WledException implements Exception {
  const WledException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Small client of the WLED JSON API, limited to what the Hub needs: check
/// the connection, read the LED count, set the brightness. The colors go
/// through DDP.
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

  /// Version, name and LED count. Throws a [WledException] (or a network
  /// error) if WLED does not answer as its API should.
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

  /// Sets the global brightness (0 – 255).
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
