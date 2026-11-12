// BuildBeacon Hub — Plugin SDK: last known state of a source.
// Version 1.5 (2026-11-12) — comments in English.

import 'localized_text.dart';
import 'status.dart';

/// Numeric value provided by a source: progress of a print, temperature,
/// today's counter…
final class Metric {
  const Metric(this.value, {this.unit, this.min, this.max});

  final double value;

  /// Unit, for the preview (`%`, `°C`, `min`…).
  final String? unit;

  /// Natural bounds of the measurement (0 – 100 for a percentage), used by
  /// the gauge when the action does not set any.
  final double? min;
  final double? max;
}

/// Last known state of a source, shared by all the zones with the same key.
///
/// Each source fills in what it can provide:
/// - GitHub: [history], the runs from newest to oldest;
/// - 3D printer: [status] (running, paused…) and [metrics]
///   (`progress`, `remaining_time`, `nozzle_temp`…);
/// - plain indicator: [metrics], and a success [status] when the read
///   succeeded (gauge color without thresholds).
final class SourceState {
  const SourceState({
    Status? status,
    this.history = const [],
    this.metrics = const {},
    this.error,
    this.updatedAt,
  }) : _status = status;

  /// Source never read: everything shows as "unknown".
  static const unknown = SourceState();

  final Status? _status;

  /// History, from newest to oldest.
  final List<Status> history;

  /// Numeric measurements, keyed by a source-specific identifier.
  final Map<String, Metric> metrics;

  /// Last read error (network, permissions, unreachable device…), shown in
  /// the interface; the previous values stay displayed.
  final LocalizedText? error;

  final DateTime? updatedAt;

  /// Current status: the one provided by the source, otherwise the newest in
  /// the history, otherwise unknown.
  Status get status => _status ?? history.firstOrNull ?? Status.unknown;

  /// Measurement [id]; without [id], the first one provided by the source.
  Metric? metric([String? id]) =>
      id == null ? metrics.values.firstOrNull : metrics[id];

  /// Same state with a read error, or without an error if [error] is null.
  SourceState withError(LocalizedText? error) => SourceState(
    status: _status,
    history: history,
    metrics: metrics,
    error: error,
    updatedAt: updatedAt,
  );
}
