// BuildBeacon Hub — Tests: output loop (send on change, keep-alive).
// Version 1.3 (2026-11-12) — test names in English.

import 'dart:typed_data';

import 'package:buildbeacon_core/buildbeacon_core.dart';
import 'package:buildbeacon_hub/buildbeacon_hub.dart';
import 'package:test/test.dart';

final class _Sink implements LedSink {
  final sent = <Uint8List>[];

  @override
  void send(Uint8List rgb) => sent.add(rgb);
}

void main() {
  late Duration now;
  late _Sink sink;
  late Rgb color;

  LedOutputLoop loop({
    LedFrame Function(Duration t)? frameAt,
    List<LocalizedText>? logs,
  }) => LedOutputLoop(
    frameAt: frameAt ?? (_) => LedFrame(2)..[0] = color,
    sink: sink,
    elapsed: () => now,
    log: logs?.add,
  );

  setUp(() {
    now = Duration.zero;
    sink = _Sink();
    color = Rgb.white;
  });

  test('first frame sent right away', () {
    expect(loop().tick(), isTrue);
    expect(sink.sent.single, [255, 255, 255, 0, 0, 0]);
  });

  test('unchanged frame: sent again only after one second', () {
    final l = loop()..tick();
    for (final ms in [50, 500, 999]) {
      now = Duration(milliseconds: ms);
      expect(l.tick(), isFalse, reason: 'at $ms ms');
    }
    now = const Duration(seconds: 1);
    expect(l.tick(), isTrue);
    expect(sink.sent, hasLength(2));
  });

  test('changed frame: sent immediately', () {
    final l = loop()..tick();
    now = const Duration(milliseconds: 50);
    color = const Rgb(255, 0, 0);
    expect(l.tick(), isTrue);
    expect(sink.sent.last.sublist(0, 3), [255, 0, 0]);
    expect(l.framesSent, 2);
  });

  test('computation error: reported once, translated, the loop goes on', () {
    final logs = <LocalizedText>[];
    final l = loop(frameAt: (_) => throw StateError('boom'), logs: logs);
    expect(l.tick(), isFalse);
    expect(l.tick(), isFalse);
    expect(sink.sent, isEmpty);
    expect(
      logs.single.resolve('fr'),
      startsWith('calcul de l\'image impossible'),
    );
    expect(logs.single.resolve('en'), contains('boom'));
  });

  test('start / stop with a real timer', () async {
    final l = LedOutputLoop(
      frameAt: (t) => LedFrame(1)..[0] = Rgb(t.inMilliseconds % 256, 0, 0),
      sink: sink,
      frameInterval: const Duration(milliseconds: 5),
    )..start();
    expect(l.isRunning, isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    l.stop();
    final sent = sink.sent.length;
    expect(sent, greaterThan(3));

    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(sink.sent, hasLength(sent));
    expect(l.isRunning, isFalse);
  });
}
