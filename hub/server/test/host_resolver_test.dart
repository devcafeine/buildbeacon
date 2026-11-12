// BuildBeacon Hub — Tests: resolving the WLED host name (system, direct mDNS).
// Version 1.2 (2026-11-12) — test names in English.

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
  group('direct mDNS query', () {
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

    test('A question for the name, answer read (compressed name)', () async {
      await respond();
      final address = await queryMdnsIPv4(
        'BuildBeacon.local',
        server: InternetAddress.loopbackIPv4,
        port: responder.port,
      );
      expect(address?.address, '192.168.1.50');

      final query = questions.first;
      expect(query.sublist(2, 6), [0, 0, 0, 1], reason: 'query, 1 question');
      expect(String.fromCharCodes(query.sublist(13, 24)), 'buildbeacon');
      expect(query.sublist(query.length - 4), [0, 1, 0, 1], reason: 'A, IN');
    });

    test('answer for another name: ignored', () async {
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
      'no answer: null after the timeout, question asked again once',
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

  test('malformed packets or questions: ignored without error', () {
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

  group('resolution order', () {
    final asked = <String>[];
    Future<InternetAddress?> fakeMdns(String name) async {
      asked.add(name);
      return InternetAddress('192.168.1.50');
    }

    setUp(asked.clear);

    test('IP address: as is, no query', () async {
      expect(
        (await resolveIPv4('192.168.1.7', mdns: fakeMdns))?.address,
        '192.168.1.7',
      );
      expect(await resolveIPv4('::1', mdns: fakeMdns), isNull);
      expect(asked, isEmpty);
    });

    test('name known to the system: no mDNS', () async {
      final address = await resolveIPv4(
        'buildbeacon.local',
        mdns: fakeMdns,
        system: (_) async => InternetAddress('10.0.0.9'),
      );
      expect(address?.address, '10.0.0.9');
      expect(asked, isEmpty);
    });

    test('.local name unknown to the system: mDNS query', () async {
      final address = await resolveIPv4(
        'tiles-test.local',
        mdns: fakeMdns,
        system: (_) async => null,
      );
      expect(address?.address, '192.168.1.50');
      expect(asked, ['tiles-test.local']);
    });

    test('other unknown name: no mDNS', () async {
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
