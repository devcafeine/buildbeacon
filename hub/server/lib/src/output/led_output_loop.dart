// BuildBeacon Hub — Output loop: computes and sends the LED frame.
// Version 1.2 (2026-11-12) — comments in English.

import 'dart:async';
import 'dart:typed_data';

import 'package:buildbeacon_core/buildbeacon_core.dart';

import 'ddp_sender.dart';

/// Computes the LED frame at a regular interval (20 frames/s by default) and
/// sends it when it changes.
///
/// An identical frame is sent again at least every [keepAlive]: without a
/// stream, WLED goes back to its own display after its realtime timeout
/// (≈ 2.5 s). A panel without animation therefore costs 1 frame/s, not 20.
final class LedOutputLoop {
  LedOutputLoop({
    required this.frameAt,
    required this.sink,
    this.frameInterval = const Duration(milliseconds: 50),
    this.keepAlive = const Duration(seconds: 1),
    Duration Function()? elapsed,
    void Function(LocalizedText message)? log,
  }) : _elapsed = elapsed ?? _stopwatch(),
       _log = log ?? _silent;

  /// Frame at time t (elapsed since startup): rendering of the sources, test
  /// pattern…
  final LedFrame Function(Duration t) frameAt;
  final LedSink sink;
  final Duration frameInterval;
  final Duration keepAlive;
  final Duration Function() _elapsed;
  final void Function(LocalizedText message) _log;

  Timer? _timer;
  Uint8List? _lastSent;
  Duration? _lastSentAt;
  var _framesSent = 0;
  String? _lastError;

  int get framesSent => _framesSent;

  bool get isRunning => _timer != null;

  void start() {
    if (_timer != null) return;
    _timer = Timer.periodic(frameInterval, (_) => tick());
    tick();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// One step of the loop; `true` if a frame was sent.
  bool tick() {
    final t = _elapsed();
    final Uint8List bytes;
    try {
      bytes = frameAt(t).toRgbBytes();
    } catch (e) {
      final error = '$e';
      if (error != _lastError) {
        _log(
          LocalizedText.build(
            (l) => tr(
              l,
              en: 'cannot compute the frame: $error',
              fr: 'calcul de l\'image impossible : $error',
            ),
          ),
        );
      }
      _lastError = error;
      return false;
    }
    _lastError = null;

    final lastAt = _lastSentAt;
    if (_sameBytes(bytes, _lastSent) &&
        lastAt != null &&
        t - lastAt < keepAlive) {
      return false;
    }
    sink.send(bytes);
    _lastSent = bytes;
    _lastSentAt = t;
    _framesSent++;
    return true;
  }

  static bool _sameBytes(Uint8List a, Uint8List? b) {
    if (b == null || a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static Duration Function() _stopwatch() {
    final watch = Stopwatch()..start();
    return () => watch.elapsed;
  }

  static void _silent(LocalizedText message) {}
}
