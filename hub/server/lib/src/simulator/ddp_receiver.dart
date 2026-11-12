// BuildBeacon Hub — Simulator: DDP reception (fake WLED).
// Version 1.1 (2026-11-12) — comments in English.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../output/ddp.dart';

/// Received frame: RGB bytes and the sender's address.
typedef ReceivedFrame = ({Uint8List rgb, InternetAddress from});

/// Fake WLED: receives the DDP packets and reassembles each frame.
///
/// A frame is emitted when the packet flagged PUSH arrives, like WLED, which
/// only displays at that moment.
final class DdpReceiver {
  DdpReceiver._(this._socket) {
    _socket.listen(_onEvent, onError: _frames.addError);
  }

  /// Listens on [port] (0 = random free port, for tests), on all interfaces
  /// by default to receive a Hub from another machine.
  static Future<DdpReceiver> bind({
    InternetAddress? address,
    int port = ddpDefaultPort,
  }) async => DdpReceiver._(
    await RawDatagramSocket.bind(address ?? InternetAddress.anyIPv4, port),
  );

  final RawDatagramSocket _socket;
  final _frames = StreamController<ReceivedFrame>.broadcast();
  var _buffer = Uint8List(0);
  var _end = 0;
  var _invalidPackets = 0;

  int get port => _socket.port;

  Stream<ReceivedFrame> get frames => _frames.stream;

  /// Ignored packets (not complete DDP v1).
  int get invalidPackets => _invalidPackets;

  Future<void> close() async {
    _socket.close();
    await _frames.close();
  }

  void _onEvent(RawSocketEvent event) {
    if (event != RawSocketEvent.read) return;
    for (var d = _socket.receive(); d != null; d = _socket.receive()) {
      _handle(d);
    }
  }

  void _handle(Datagram datagram) {
    final packet = DdpPacket.tryParse(datagram.data);
    if (packet == null) {
      _invalidPackets++;
      return;
    }
    final end = packet.offset + packet.data.length;
    if (end > _buffer.length) {
      _buffer = Uint8List(end)..setRange(0, _buffer.length, _buffer);
    }
    _buffer.setRange(packet.offset, end, packet.data);
    if (end > _end) _end = end;
    if (packet.push) {
      _frames.add((rgb: _buffer.sublist(0, _end), from: datagram.address));
      _end = 0;
    }
  }
}
