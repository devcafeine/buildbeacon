// BuildBeacon Hub — Sending frames to WLED over DDP (UDP).
// Version 1.4 (2026-11-12) — comments in English.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:buildbeacon_core/buildbeacon_core.dart';

import 'ddp.dart';
import 'host_resolver.dart';

/// Destination of the LED frames: WLED, simulator, test.
abstract interface class LedSink {
  /// Sends a frame: R, G, B bytes in sequence, in chain order.
  void send(Uint8List rgb);
}

/// Sends the frames to WLED over DDP.
///
/// [host] can be an mDNS name (`buildbeacon.local`), a DNS name or an IPv4
/// address. An address is used right away; a name is resolved in the
/// background (several seconds for an mDNS name missing from the network),
/// then every `refresh`: the address of an ESP32 can change. On failure, the
/// last known address is kept; without an address, nothing is sent.
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
    // Do not wait for the resolution: it would delay the Hub's startup and
    // the saving of a configuration.
    if (InternetAddress.tryParse(host) case final ip?
        when ip.type == InternetAddressType.IPv4) {
      sender._use(ip);
    }
    unawaited(sender._refreshAddress());
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

  /// Resolved address of WLED; `null` as long as [host] cannot be found.
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
    if (address != known) _use(address);
  }

  void _use(InternetAddress address) {
    _address = address;
    _lastWarning = null;
    _log(LocalizedText.same('WLED: $host → ${address.address}:$port'));
  }

  /// The same warning is logged only once in a row.
  void _warn(LocalizedText message) {
    final key = message.resolve(fallbackLanguage);
    if (key == _lastWarning) return;
    _lastWarning = key;
    _log(message);
  }

  static void _silent(LocalizedText message) {}
}
