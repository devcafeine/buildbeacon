// BuildBeacon Hub — Plugin SDK: test harness for plugin tests.
// Version 1.2 (2026-11-12) — comments in English.

import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../localized_text.dart';
import '../source_plugin.dart';
import '../source_settings.dart';
import '../source_state.dart';
import '../validation.dart';

/// Simulated response of an HTTP service.
typedef FakeHttpHandler =
    FutureOr<http.Response> Function(http.Request request);

/// Test context: HTTP simulated by [respond] (without it, every request
/// fails), secrets, polling interval and clock.
///
/// The default interval (1 h) guarantees a single read during a test;
/// shorten it to observe several reads with [firstStates].
PluginContext fakeContext({
  FakeHttpHandler? respond,
  Map<String, String> secrets = const {},
  Duration pollInterval = const Duration(hours: 1),
  DateTime Function()? clock,
  void Function(String message)? log,
}) => PluginContext(
  httpClient: MockClient((request) async {
    if (respond == null) {
      throw StateError(
        'unexpected HTTP request: ${request.method} ${request.url}',
      );
    }
    return respond(request);
  }),
  pollInterval: pollInterval,
  secrets: secrets,
  clock: clock,
  log: log,
);

/// Opens [plugin] with [settings], as the Hub would, and returns the first
/// state emitted.
///
/// The settings are validated first: if they are invalid, throws an
/// [ArgumentError] that lists the problems.
Future<SourceState> firstState(
  SourcePlugin plugin,
  Map<String, Object?> settings, {
  PluginContext? context,
  Duration timeout = const Duration(seconds: 5),
}) async => (await firstStates(
  plugin,
  settings,
  1,
  context: context,
  timeout: timeout,
)).single;

/// The first [count] states emitted by [plugin] (see [firstState]). For a
/// polled source, shorten `pollInterval` in [context].
Future<List<SourceState>> firstStates(
  SourcePlugin plugin,
  Map<String, Object?> settings,
  int count, {
  PluginContext? context,
  Duration timeout = const Duration(seconds: 5),
}) {
  final issues = settingsIssues(plugin, settings);
  if (issues.isNotEmpty) {
    throw ArgumentError(
      'Invalid settings for "${plugin.type}": '
      '${issues.resolveAll(fallbackLanguage).join('; ')}',
    );
  }
  return plugin
      .connect(SourceSettings(settings), context ?? fakeContext())
      .take(count)
      .toList()
      .timeout(timeout);
}
