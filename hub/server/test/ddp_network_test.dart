// BuildBeacon Hub — Tests: sending and receiving DDP over UDP on loopback.
// Version 1.3 (2026-11-12) — comments in English.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:buildbeacon_core/buildbeacon_core.dart';
import 'package:buildbeacon_hub/buildbeacon_hub.dart';
import 'package:test/test.dart';

void main() {
  late DdpReceiver receiver;

  setUp(() async {
    receiver = await DdpReceiver.bind(
      address: InternetAddress.loopbackIPv4,
      port: 0,
    );
  });

  tearDown(() => receiver.close());

  Future<ReceivedFrame> roundTrip(Uint8List rgb) async {
    final sender = await DdpSender.open(host: '127.0.0.1', port: receiver.port);
    final received = receiver.frames.first;
    sender.send(rgb);
    try {
      return await received.timeout(const Duration(seconds: 5));
    } finally {
      await sender.close();
    }
  }

  test('émetteur → faux WLED : image reçue à l\'identique', () async {
    final rgb = Uint8List.fromList(List.generate(63, (i) => i * 4));
    final frame = await roundTrip(rgb);
    expect(frame.rgb, rgb);
    expect(frame.from.address, '127.0.0.1');
  });

  test('600 LED : plusieurs paquets, image reconstituée', () async {
    final rgb = Uint8List.fromList(List.generate(1800, (i) => i % 251));
    expect((await roundTrip(rgb)).rgb, rgb);
  });

  test('paquet qui n\'est pas du DDP : ignoré et compté', () async {
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    socket.send([1, 2, 3], InternetAddress.loopbackIPv4, receiver.port);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    socket.close();
    expect(receiver.invalidPackets, 1);
  });

  group('adresse de WLED', () {
    test('IP, nom local, IPv6 refusée', () async {
      expect((await resolveIPv4('192.168.1.50'))?.address, '192.168.1.50');
      expect((await resolveIPv4('localhost'))?.address, '127.0.0.1');
      expect(await resolveIPv4('::1'), isNull);
    });

    test('ouverture immédiate : une IP sert tout de suite, un nom se résout '
        'en arrière-plan', () async {
      final resolved = Completer<InternetAddress?>();
      final byName = await DdpSender.open(
        host: 'buildbeacon.local',
        resolve: (_) => resolved.future,
      ).timeout(const Duration(seconds: 1));
      expect(byName.address, isNull);
      resolved.complete(InternetAddress('192.168.1.50'));
      await pumpEventQueue();
      expect(byName.address?.address, '192.168.1.50');
      await byName.close();

      final byIp = await DdpSender.open(
        host: '192.168.1.51',
        resolve: (_) => Completer<InternetAddress?>().future,
      );
      expect(byIp.address?.address, '192.168.1.51');
      await byIp.close();
    });

    test(
      'nom introuvable : rien n\'est envoyé, un seul avertissement traduit',
      () async {
        final logs = <LocalizedText>[];
        final sender = await DdpSender.open(
          host: 'tiles.invalid',
          resolve: (_) async => null,
          log: logs.add,
        );
        sender
          ..send(Uint8List(3))
          ..send(Uint8List(3));
        await sender.close();

        expect(sender.address, isNull);
        expect(sender.packetsSent, 0);
        expect(
          logs.single.resolve('fr'),
          contains('« tiles.invalid » introuvable'),
        );
        expect(
          logs.single.resolve('en'),
          contains('"tiles.invalid" not found'),
        );
      },
    );
  });
}
