// BuildBeacon Hub — Résolution du nom de WLED : système, puis mDNS direct pour les noms .local.
// Version 1.0 (2026-11-12) — extrait de ddp_sender.dart ; requête mDNS ponctuelle (Docker).

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

/// Résolution d'un nom en adresse IPv4 ; `null` si impossible.
typedef HostResolver = Future<InternetAddress?> Function(String host);

/// Requête mDNS d'un nom `.local` ; `null` sans réponse.
typedef MdnsQuery = Future<InternetAddress?> Function(String name);

/// Adresse IPv4 de [host] : adresse IP telle quelle, sinon résolution du
/// système, sinon, pour un nom `.local` (`buildbeacon.local`), requête mDNS
/// directe ([queryMdnsIPv4]).
///
/// Le système résout les noms `.local` sur macOS, ou sur un Linux avec Avahi
/// et nss-mdns ; pas dans un conteneur Docker, d'où la requête directe.
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

/// Résolution par le système (fichier hosts, DNS, mDNS selon la machine).
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

/// Groupe et port mDNS (RFC 6762).
final mdnsGroup = InternetAddress('224.0.0.251');
const mdnsPort = 5353;

/// Adresse IPv4 de [name] par une requête mDNS « ponctuelle » (RFC 6762,
/// § 5.1) : la question part vers le groupe mDNS depuis un port quelconque, et
/// les répondeurs (WLED, Avahi, macOS) répondent directement à ce port. Il
/// n'est donc pas nécessaire d'écouter le port 5353, souvent déjà pris par le
/// démon mDNS de la machine, ni d'avoir un démon dans le conteneur.
///
/// La question est reposée une fois à mi-délai (paquet UDP perdu). [server]
/// et [port] servent aux tests.
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
      // Pas d'interface réseau : pas de réponse, délai écoulé.
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

/// Question DNS « A, IN » pour [name], au format des paquets mDNS.
Uint8List encodeMdnsQuery(String name, {required int id}) {
  final bytes = BytesBuilder()
    ..add([id >> 8, id & 0xFF]) // identifiant (renvoyé par le répondeur)
    ..add([0, 0]) // drapeaux : requête standard
    ..add([0, 1, 0, 0, 0, 0, 0, 0]); // 1 question, 0 réponse
  for (final label in _labels(name)) {
    final ascii = label.codeUnits;
    bytes
      ..addByte(ascii.length)
      ..add(ascii);
  }
  bytes
    ..addByte(0)
    ..add([0, 1]) // type A
    ..add([0, 1]); // classe IN
  return bytes.takeBytes();
}

/// Adresse IPv4 donnée pour [name] dans le paquet de réponse [packet]
/// (réponses et informations additionnelles) ; `null` sinon, ou si le
/// paquet est malformé.
InternetAddress? decodeMdnsAnswer(Uint8List packet, String name) {
  final wanted = _labels(name).join('.');
  try {
    final data = ByteData.sublistView(packet);
    final flags = data.getUint16(2);
    if (flags & 0x8000 == 0) return null; // une question, pas une réponse
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

/// Étiquettes d'un nom, en minuscules, sans point final.
List<String> _labels(String name) => [
  for (final label in name.toLowerCase().split('.'))
    if (label.isNotEmpty) label,
];

/// Nom à [offset] (étiquettes, avec les pointeurs de compression DNS) et
/// position juste après lui.
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
