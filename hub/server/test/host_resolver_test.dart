// BuildBeacon Hub — Tests: resolving the WLED host name (system, direct mDNS).
// Version 1.1 (2026-11-12) — comments in English.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:buildbeacon_hub/buildbeacon_hub.dart';
import 'package:test/test.dart';

/// mDNS answer for [name] → [ip], the answer's name being a pointer to the
/// question's name (DNS compression), as most responders do.
Uint8List _answer(Uint8List query, List<int> ip, {bool sameName = true}) {
  final question = query.sublist(12);
  final bytes = BytesBuilder()
    ..add([query[0], query[1]]) // same ID
    ..add([0x84, 0x00]) // response, authoritative
    ..add([0, 1, 0, 1, 0, 0, 0, 0]) // the question, 1 answer
    ..add(question)
    ..add(
      sameName
          ? [0xC0, 12]
          : [5, ...'other'.codeUnits, 5, ...'local'.codeUnits, 0],
    )
    ..add([0, 1, 0x80, 1]) // A, IN ("cache flush" bit)
    ..add([0, 0, 0, 120]) // time to live
    ..add([0, 4, ...ip]);
  return bytes.takeBytes();
}

void main() {
  group('requête mDNS directe', () {
    late RawDatagramSocket responder;
    final questions = <Uint8List>[];

    Future<void> respond({bool sameName = true, bool silent = false}) async {
      responder = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
      responder.listen((event) {
        if (event != RawSocketEvent.read) return;
        final datagram = responder.receive();
        if (datagram == null) return;
        questions.add(datagram.data);
        if (silent) return;
        responder.send(
          _answer(datagram.data, [192, 168, 1, 50], sameName: sameName),
          datagram.address,
          datagram.port,
        );
      });
    }

    setUp(questions.clear);
    tearDown(() => responder.close());

    test('question A pour le nom, réponse lue (nom compressé)', () async {
      await respond();
      final address = await queryMdnsIPv4(
        'BuildBeacon.local',
        server: InternetAddress.loopbackIPv4,
        port: responder.port,
      );
      expect(address?.address, '192.168.1.50');

      final query = questions.first;
      expect(query.sublist(2, 6), [0, 0, 0, 1], reason: 'requête, 1 question');
      expect(String.fromCharCodes(query.sublist(13, 24)), 'buildbeacon');
      expect(query.sublist(query.length - 4), [0, 1, 0, 1], reason: 'A, IN');
    });

    test('réponse pour un autre nom : ignorée', () async {
      await respond(sameName: false);
      final address = await queryMdnsIPv4(
        'buildbeacon.local',
        server: InternetAddress.loopbackIPv4,
        port: responder.port,
        timeout: const Duration(milliseconds: 300),
      );
      expect(address, isNull);
    });

    test(
      'pas de réponse : null après le délai, question reposée une fois',
      () async {
        await respond(silent: true);
        final watch = Stopwatch()..start();
        final address = await queryMdnsIPv4(
          'buildbeacon.local',
          server: InternetAddress.loopbackIPv4,
          port: responder.port,
          timeout: const Duration(milliseconds: 300),
        );
        expect(address, isNull);
        expect(watch.elapsedMilliseconds, lessThan(1000));
        expect(questions, hasLength(2));
      },
    );
  });

  test('paquets malformés ou questions : ignorés sans erreur', () {
    final query = encodeMdnsQuery('buildbeacon.local', id: 7);
    expect(decodeMdnsAnswer(query, 'buildbeacon.local'), isNull);
    expect(decodeMdnsAnswer(Uint8List(5), 'buildbeacon.local'), isNull);
    final truncated = _answer(query, [10, 0, 0, 1]);
    expect(
      decodeMdnsAnswer(
        truncated.sublist(0, truncated.length - 3),
        'buildbeacon.local',
      ),
      isNull,
    );
    expect(
      decodeMdnsAnswer(truncated, 'buildbeacon.local')?.address,
      '10.0.0.1',
    );
  });

  group('ordre de résolution', () {
    final asked = <String>[];
    Future<InternetAddress?> fakeMdns(String name) async {
      asked.add(name);
      return InternetAddress('192.168.1.50');
    }

    setUp(asked.clear);

    test('adresse IP : telle quelle, sans requête', () async {
      expect(
        (await resolveIPv4('192.168.1.7', mdns: fakeMdns))?.address,
        '192.168.1.7',
      );
      expect(await resolveIPv4('::1', mdns: fakeMdns), isNull);
      expect(asked, isEmpty);
    });

    test('nom connu du système : sans mDNS', () async {
      final address = await resolveIPv4(
        'buildbeacon.local',
        mdns: fakeMdns,
        system: (_) async => InternetAddress('10.0.0.9'),
      );
      expect(address?.address, '10.0.0.9');
      expect(asked, isEmpty);
    });

    test('nom .local inconnu du système : requête mDNS', () async {
      final address = await resolveIPv4(
        'tiles-test.local',
        mdns: fakeMdns,
        system: (_) async => null,
      );
      expect(address?.address, '192.168.1.50');
      expect(asked, ['tiles-test.local']);
    });

    test('autre nom inconnu : pas de mDNS', () async {
      expect(
        await resolveIPv4(
          'tiles.invalid',
          mdns: fakeMdns,
          system: (_) async => null,
        ),
        isNull,
      );
      expect(asked, isEmpty);
    });
  });
}
