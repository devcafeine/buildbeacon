// BuildBeacon Hub — Resolving the WLED name: system first, then direct mDNS for .local names.
// Version 1.1 (2026-11-12) — comments in English.

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

/// Resolution of a name to an IPv4 address; `null` if impossible.
typedef HostResolver = Future<InternetAddress?> Function(String host);

/// mDNS query for a `.local` name; `null` without an answer.
typedef MdnsQuery = Future<InternetAddress?> Function(String name);

/// IPv4 address of [host]: an IP address as is, otherwise the system
/// resolution, otherwise, for a `.local` name (`buildbeacon.local`), a direct
/// mDNS query ([queryMdnsIPv4]).
///
/// The system resolves `.local` names on macOS, or on Linux with Avahi and
/// nss-mdns; not in a Docker container, hence the direct query.
Future<InternetAddress?> resolveIPv4(
  String host, {
  MdnsQuery mdns = queryMdnsIPv4,
  HostResolver system = _systemLookup,
}) async {
  final literal = InternetAddress.tryParse(host);
  if (literal != null) {
    return literal.type == InternetAddressType.IPv4 ? literal : null;
  }
  if (await system(host) case final address?) return address;
  final name = host.toLowerCase();
  return name.endsWith('.local') || name.endsWith('.local.')
      ? mdns(host)
      : null;
}

/// Resolution by the system (hosts file, DNS, mDNS depending on the machine).
Future<InternetAddress?> _systemLookup(String host) async {
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

/// mDNS group and port (RFC 6762).
final mdnsGroup = InternetAddress('224.0.0.251');
const mdnsPort = 5353;

/// IPv4 address of [name] through a "one-shot" mDNS query (RFC 6762,
/// § 5.1): the question is sent to the mDNS group from any port, and the
/// responders (WLED, Avahi, macOS) answer directly to that port. So there is
/// no need to listen on port 5353, often already taken by the machine's mDNS
/// daemon, nor to have a daemon in the container.
///
/// The question is asked again once halfway through the timeout (lost UDP
/// packet). [server] and [port] are for tests.
Future<InternetAddress?> queryMdnsIPv4(
  String name, {
  Duration timeout = const Duration(seconds: 2),
  InternetAddress? server,
  int port = mdnsPort,
}) async {
  final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
  final id = Random().nextInt(0xFFFE) + 1;
  final query = encodeMdnsQuery(name, id: id);
  final target = server ?? mdnsGroup;
  final answer = Completer<InternetAddress?>();

  final subscription = socket.listen((event) {
    if (event != RawSocketEvent.read) return;
    final datagram = socket.receive();
    if (datagram == null || answer.isCompleted) return;
    final address = decodeMdnsAnswer(datagram.data, name);
    if (address != null) answer.complete(address);
  });
  void ask() {
    try {
      socket.send(query, target, port);
    } on SocketException {
      // No network interface: no answer, the timeout expires.
    }
  }

  ask();
  final retry = Timer(timeout ~/ 2, ask);
  try {
    return await answer.future.timeout(timeout, onTimeout: () => null);
  } finally {
    retry.cancel();
    await subscription.cancel();
    socket.close();
  }
}

/// DNS "A, IN" question for [name], in the mDNS packet format.
Uint8List encodeMdnsQuery(String name, {required int id}) {
  final bytes = BytesBuilder()
    ..add([id >> 8, id & 0xFF]) // identifier (echoed by the responder)
    ..add([0, 0]) // flags: standard query
    ..add([0, 1, 0, 0, 0, 0, 0, 0]); // 1 question, 0 answers
  for (final label in _labels(name)) {
    final ascii = label.codeUnits;
    bytes
      ..addByte(ascii.length)
      ..add(ascii);
  }
  bytes
    ..addByte(0)
    ..add([0, 1]) // type A
    ..add([0, 1]); // class IN
  return bytes.takeBytes();
}

/// IPv4 address given for [name] in the response packet [packet] (answers
/// and additional records); `null` otherwise, or if the packet is
/// malformed.
InternetAddress? decodeMdnsAnswer(Uint8List packet, String name) {
  final wanted = _labels(name).join('.');
  try {
    final data = ByteData.sublistView(packet);
    final flags = data.getUint16(2);
    if (flags & 0x8000 == 0) return null; // a question, not an answer
    final questions = data.getUint16(4);
    final records = data.getUint16(6) + data.getUint16(8) + data.getUint16(10);
    var offset = 12;
    for (var i = 0; i < questions; i++) {
      offset = _readName(packet, offset).$2 + 4;
    }
    for (var i = 0; i < records; i++) {
      final (recordName, next) = _readName(packet, offset);
      final type = data.getUint16(next);
      final length = data.getUint16(next + 8);
      final rdata = next + 10;
      if (type == 1 && length == 4 && recordName == wanted) {
        return InternetAddress.fromRawAddress(
          packet.sublist(rdata, rdata + 4),
          type: InternetAddressType.IPv4,
        );
      }
      offset = rdata + length;
    }
  } on RangeError {
    return null;
  }
  return null;
}

/// Labels of a name, in lower case, without a trailing dot.
List<String> _labels(String name) => [
  for (final label in name.toLowerCase().split('.'))
    if (label.isNotEmpty) label,
];

/// Name at [offset] (labels, following DNS compression pointers) and the
/// position right after it.
(String, int) _readName(Uint8List packet, int offset) {
  final labels = <String>[];
  var position = offset;
  int? end;
  for (var jumps = 0; jumps < 64; jumps++) {
    final length = packet[position];
    if (length == 0) {
      return (labels.join('.').toLowerCase(), end ?? position + 1);
    }
    if (length & 0xC0 == 0xC0) {
      end ??= position + 2;
      position = ((length & 0x3F) << 8) | packet[position + 1];
      continue;
    }
    labels.add(
      String.fromCharCodes(packet.sublist(position + 1, position + 1 + length)),
    );
    position += 1 + length;
  }
  throw RangeError('DNS name: too many labels or a pointer loop');
}
