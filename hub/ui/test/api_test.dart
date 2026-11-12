// BuildBeacon UI — Tests: API client, SSE stream, parsing of the Hub's responses.
// Version 1.2 (2026-11-12) — test names in English.

import 'package:buildbeacon_core/buildbeacon_core.dart';
import 'package:buildbeacon_ui/src/api/hub_api.dart';
import 'package:buildbeacon_ui/src/api/hub_events.dart';
import 'package:buildbeacon_ui/src/api/live_state.dart';
import 'package:buildbeacon_ui/src/api/plugin_info.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_hub.dart';

void main() {
  group('SSE stream', () {
    Future<List<(String, String)>> parse(List<String> chunks) async => [
      for (final m in await parseServerSentEvents(
        Stream.fromIterable(chunks),
      ).toList())
        (m.name, m.data),
    ];

    test('named events, comments ignored', () async {
      expect(
        await parse([
          'event: config\ndata: {"a":1}\n\n',
          ': ping\n\n',
          'event: state\ndata: {"b":2}\n\n',
        ]),
        [('config', '{"a":1}'), ('state', '{"b":2}')],
      );
    });

    test('message split across two packets, data on several lines', () async {
      expect(await parse(['event: sta', 'te\ndata: un\nda', 'ta: deux\n\n']), [
        ('state', 'un\ndeux'),
      ]);
    });

    test('no name: "message"', () async {
      expect(await parse(['data:x\n\n']), [('message', 'x')]);
    });
  });

  test('plugin description', () {
    final [github, printer] = [
      for (final p in pluginsJson['plugins']!)
        PluginInfo.fromJson(p as Map<String, Object?>),
    ];
    expect(github.type, 'github');
    expect(github.label.resolve('fr'), 'GitHub Actions');
    expect(github.settings.first.required, isTrue);
    expect(github.settings.first.validate('pas un dépôt'), hasLength(1));
    expect(github.secrets.single.configured, isFalse);
    expect(github.supports(DisplayMode.history), isTrue);
    expect(github.supports(DisplayMode.gauge), isFalse);

    expect(printer.metrics.single.unit, '%');
    expect(printer.metrics.single.max, 100);
    expect(printer.supports(DisplayMode.gauge), isTrue);
    expect(printer.supports(DisplayMode.history), isFalse);
  });

  test('live state', () {
    final live = LiveState.fromJson(stateJson(identifying: ['site']));
    expect(live.sources[sourceKey]!.status, Status.failure);
    expect(live.sources[sourceKey]!.history, hasLength(3));
    expect(live.identifying, {'site'});
    expect(live.animated, isTrue);
    expect(live.wled.ledCount, 21);
    expect(live.wled.reachable, isTrue);
    expect(LiveState.fromJson(stateJson()).animated, isFalse);
  });

  group('client', () {
    test('reading the configuration and plugins', () async {
      final api = FakeHub().api();
      expect((await api.config()).tiles, hasLength(3));
      expect(await api.plugins(), hasLength(2));
    });

    test('API address relative to the page', () {
      final api = HubApi(base: Uri.parse('http://hub.local:8080/'));
      expect(api.url('events').toString(), 'http://hub.local:8080/api/events');
      final proxied = HubApi(base: Uri.parse('https://example.org/beacon/'));
      expect(
        proxied.url('config').toString(),
        'https://example.org/beacon/api/config',
      );
    });

    test('configuration rejected: translated issues (422)', () async {
      final api = FakeHub().api();
      final config = Config.fromJson(
        configJson()
          ..['tiles'] = [
            {
              'id': 'master',
              'kind': 'master',
              'chain_index': 0,
              'pos': {'q': 0, 'r': 0},
              'zones': {
                'system': {
                  'source': {'type': 'github'},
                  'mode': 'overall',
                },
              },
            },
          ],
      );
      await expectLater(
        api.saveConfig(config),
        throwsA(
          isA<ApiException>()
              .having((e) => e.status, 'status', 422)
              .having(
                (e) => e.issues.single.resolve('fr'),
                'issue',
                contains('Dépôt'),
              ),
        ),
      );
    });

    test('token: 401 without it, accepted with it', () async {
      final api = FakeHub(apiToken: 'secret').api();
      await expectLater(
        api.identify('app'),
        throwsA(isA<ApiException>().having((e) => e.unauthorized, '401', true)),
      );
      api.token = 'secret';
      await api.identify('app');
    });

    test('silent stream: polling until the first event', () async {
      final hub = FakeHub();
      final api = hub.api(eventsPatience: const Duration(milliseconds: 30));
      final received = <String>[];
      final subscription = api.events().listen(
        (e) => received.add(switch (e) {
          HubMessage(:final name) => name,
          HubLinkChanged(:final open) => open ? 'open' : 'closed',
        }),
      );
      // The stream reports that it is open, but sends nothing.
      hub.events.add(const HubLinkChanged(open: true));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(received.first, 'open');
      expect(received.skip(1).take(3), ['open', 'config', 'state']);
      expect(hub.requests, contains('GET /api/state'));

      // The stream starts sending: polling stops.
      hub.sendState(stateJson());
      await Future<void>.delayed(Duration.zero);
      final count = hub.requests.length;
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(hub.requests.length, count);
      expect(received.last, 'state');
      await subscription.cancel();
    });

    test('active stream: no polling', () async {
      final hub = FakeHub();
      final api = hub.api(eventsPatience: const Duration(milliseconds: 30));
      final subscription = api.events().listen((_) {});
      hub.sendConfig(configJson());
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(hub.requests, isNot(contains('GET /api/state')));
      await subscription.cancel();
    });

    test('Hub unreachable', () async {
      final hub = FakeHub()..reachable = false;
      await expectLater(
        hub.api().config(),
        throwsA(isA<ApiException>().having((e) => e.unreachable, '0', true)),
      );
    });
  });
}
