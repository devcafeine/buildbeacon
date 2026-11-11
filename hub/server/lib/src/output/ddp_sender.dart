// BuildBeacon Hub — Envoi des images à WLED en DDP (UDP).
// Version 1.1 (2026-11-11) — messages du journal traduits (LocalizedText).

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:buildbeacon_core/buildbeacon_core.dart';

import 'ddp.dart';

/// Destination des images de LED : WLED, simulateur, test.
abstract interface class LedSink {
  /// Envoie une image : octets R, G, B à la suite, dans l'ordre de la chaîne.
  void send(Uint8List rgb);
}

/// Résolution d'un nom en adresse IPv4 ; `null` si impossible.
typedef HostResolver = Future<InternetAddress?> Function(String host);

/// Envoie les images à WLED en DDP.
///
/// [host] peut être un nom mDNS (`buildbeacon.local`), un nom DNS ou une
/// adresse IPv4. Il est résolu à l'ouverture puis toutes les `refresh` :
/// l'adresse d'un ESP32 peut changer. En cas d'échec, la dernière adresse
/// connue est gardée ; sans adresse, rien n'est envoyé.
final class DdpSender implements LedSink {
  DdpSender._(this.host, this.port, this._socket, this._resolve, this._log);

  static Future<DdpSender> open({
    required String host,
    int port = ddpDefaultPort,
    Duration refresh = const Duration(minutes: 5),
    HostResolver? resolve,
    void Function(LocalizedText message)? log,
  }) async {
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    final sender = DdpSender._(
      host,
      port,
      socket,
      resolve ?? resolveIPv4,
      log ?? _silent,
    );
    socket.listen(
      (_) {},
      onError: (Object error) => sender._warn(
        LocalizedText.build(
          (l) =>
              tr(l, en: 'network error: $error', fr: 'erreur réseau : $error'),
        ),
      ),
    );
    await sender._refreshAddress();
    sender._timer = Timer.periodic(
      refresh,
      (_) => unawaited(sender._refreshAddress()),
    );
    return sender;
  }

  final String host;
  final int port;
  final RawDatagramSocket _socket;
  final HostResolver _resolve;
  final void Function(LocalizedText message) _log;

  Timer? _timer;
  InternetAddress? _address;
  var _sequence = 0;
  var _packetsSent = 0;
  String? _lastWarning;

  /// Adresse résolue de WLED ; `null` tant que [host] est introuvable.
  InternetAddress? get address => _address;

  int get packetsSent => _packetsSent;

  @override
  void send(Uint8List rgb) {
    final address = _address;
    if (address == null) return;
    _sequence = _sequence % 15 + 1;
    for (final packet in encodeDdp(rgb, sequence: _sequence)) {
      try {
        _socket.send(packet, address, port);
        _packetsSent++;
      } on SocketException catch (e) {
        _warn(
          LocalizedText.build(
            (l) => tr(
              l,
              en: 'cannot send to ${address.address}:$port: ${e.message}',
              fr:
                  'envoi vers ${address.address}:$port impossible : '
                  '${e.message}',
            ),
          ),
        );
        return;
      }
    }
  }

  Future<void> close() async {
    _timer?.cancel();
    _socket.close();
  }

  Future<void> _refreshAddress() async {
    final address = await _resolve(host);
    final known = _address;
    if (address == null) {
      _warn(
        known == null
            ? LocalizedText.build(
                (l) => tr(
                  l,
                  en:
                      '"$host" not found: nothing is sent (check the name, '
                      'or give the IP address of WLED)',
                  fr:
                      '« $host » introuvable : rien n\'est envoyé (vérifier '
                      'le nom, ou indiquer l\'adresse IP de WLED)',
                ),
              )
            : LocalizedText.build(
                (l) => tr(
                  l,
                  en:
                      '"$host" not found, keeping the last address: '
                      '${known.address}',
                  fr:
                      '« $host » introuvable, dernière adresse gardée : '
                      '${known.address}',
                ),
              ),
      );
      return;
    }
    if (address != known) {
      _address = address;
      _lastWarning = null;
      _log(LocalizedText.same('WLED: $host → ${address.address}:$port'));
    }
  }

  /// Un même avertissement n'est journalisé qu'une fois de suite.
  void _warn(LocalizedText message) {
    final key = message.resolve(fallbackLanguage);
    if (key == _lastWarning) return;
    _lastWarning = key;
    _log(message);
  }

  static void _silent(LocalizedText message) {}
}

/// Résout [host] en adresse IPv4 (WLED sur ESP32 est en IPv4).
Future<InternetAddress?> resolveIPv4(String host) async {
  final literal = InternetAddress.tryParse(host);
  if (literal != null) {
    return literal.type == InternetAddressType.IPv4 ? literal : null;
  }
  try {
    final found = await InternetAddress.lookup(
      host,
      type: InternetAddressType.IPv4,
    );
    return found.firstOrNull;
  } on SocketException {
    return null;
  }
}
