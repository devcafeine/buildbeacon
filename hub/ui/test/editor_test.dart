// BuildBeacon UI — Tests: draft, chain, saving, changes coming from the Hub.
// Version 1.2 (2026-11-12) — test names in English.

import 'package:buildbeacon_core/buildbeacon_core.dart';
import 'package:buildbeacon_ui/src/api/hub_events.dart';
import 'package:buildbeacon_ui/src/editor/editor_controller.dart';
import 'package:buildbeacon_ui/src/editor/model_edit.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_hub.dart';

void main() {
  late FakeHub hub;
  late EditorController editor;

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  setUp(() async {
    hub = FakeHub();
    editor = EditorController(hub.api(), validationDelay: Duration.zero);
    await editor.start();
  });

  tearDown(() => editor.dispose());

  Map<String, int> chain() => {
    for (final t in editor.draft!.tiles) t.id: t.chainIndex,
  };

  test('loading: configuration and plugins, nothing to save', () {
    expect(editor.loadError, isNull);
    expect(editor.draft!.tiles, hasLength(3));
    expect(editor.plugins.map((p) => p.type), ['github', 'printer']);
    expect(editor.dirty, isFalse);
  });

  group('tiles', () {
    test('add: at the end of the chain, selected', () {
      final id = editor.addTile(const HexPos(1, 0));
      expect(id, 'tile-3');
      expect(editor.selectedTileId, 'tile-3');
      expect(chain()['tile-3'], 3);
      expect(editor.dirty, isTrue);
      expect(editor.addTile(const HexPos(1, 0)), isNull, reason: 'cell taken');
    });

    test('remove: the following tiles move up; can be undone', () {
      final before = editor.removeTile('app');
      expect(chain(), {'master': 0, 'site': 1});
      editor.restore(before!);
      expect(editor.dirty, isFalse);
      expect(
        editor.removeTile('master'),
        isNull,
        reason: 'the master tile stays',
      );
    });

    test('move: to a free cell, or swap places', () {
      editor.moveTile('site', const HexPos(2, 0));
      expect(editor.draft!.tile('site')!.pos, const HexPos(2, 0));
      editor.moveTile('site', const HexPos(0, 0));
      expect(editor.draft!.tile('site')!.pos, const HexPos(0, 0));
      expect(editor.draft!.tile('app')!.pos, const HexPos(2, 0));
    });

    test('chain order', () {
      editor.addTile(const HexPos(1, 0));
      editor.moveInChain(2, 0);
      expect(chain(), {'master': 0, 'app': 2, 'site': 3, 'tile-3': 1});
    });

    test('id: empty or already taken is rejected; the selection follows', () {
      editor.select('app');
      expect(editor.renameTile('app', 'site'), isFalse);
      expect(editor.renameTile('app', '  '), isFalse);
      expect(editor.renameTile('app', ' frontend '), isTrue);
      expect(editor.selectedTileId, 'frontend');
      expect(editor.draft!.tile('frontend'), isNotNull);
    });

    test(
      'zone turned on: same source as the other zone, history on the dots',
      () {
        final site = editor.draft!.tile('site')!;
        final dots = editor.defaultAction(site, ZoneName.dots);
        expect(dots.source.type, 'github');
        expect(dots.mode, DisplayMode.history);

        final app = editor.draft!.tile('app')!.withZone(ZoneName.dots, null);
        final action = editor.defaultAction(app, ZoneName.dots);
        expect(action.source.settings, {'repo': 'acme/app'});
        expect(
          editor.defaultAction(app, ZoneName.ambient).mode,
          DisplayMode.overall,
        );
      },
    );
  });

  group('validation and saving', () {
    test('issues reported by the Hub while typing', () async {
      editor.setZone(
        'site',
        ZoneName.ambient,
        ZoneAction(
          source: SourceConfig(type: 'github'),
          mode: DisplayMode.overall,
        ),
      );
      expect(editor.validating, isTrue);
      await settle();
      await settle();
      expect(editor.validating, isFalse);
      expect(editor.issues.single.resolve('fr'), contains('Dépôt'));

      editor.discard();
      expect(editor.issues, isEmpty);
      expect(editor.dirty, isFalse);
    });

    test('saved: the draft becomes the Hub configuration', () async {
      editor.updateTile('app', (t) => t.copyWith(label: 'Frontend'));
      expect(await editor.save(), SaveResult.saved);
      expect(editor.dirty, isFalse);
      expect(hub.requests, contains('PUT /api/config'));
      expect(
        (hub.config['tiles']! as List)[1],
        containsPair('label', 'Frontend'),
      );
    });

    test('rejected (422): issues shown, draft kept', () async {
      editor.setZone(
        'site',
        ZoneName.dots,
        ZoneAction(
          source: SourceConfig(type: 'github'),
          mode: DisplayMode.history,
        ),
      );
      expect(await editor.save(), SaveResult.rejected);
      expect(editor.dirty, isTrue);
      expect(editor.issues, hasLength(1));
    });

    test('token required', () async {
      hub = FakeHub(apiToken: 'secret');
      final protected = EditorController(
        hub.api(),
        validationDelay: Duration.zero,
      );
      addTearDown(protected.dispose);
      await protected.start();
      protected.setPollSeconds(120);
      expect(await protected.save(), SaveResult.unauthorized);
      protected.api.token = 'secret';
      expect(await protected.save(), SaveResult.saved);
    });
  });

  group('Hub events', () {
    test('live state', () async {
      hub.sendState(stateJson(identifying: ['app']));
      await settle();
      expect(editor.link, HubLink.live);
      expect(editor.live.identifying, {'app'});
      final app = editor.draft!.tile('app')!;
      expect(
        editor.stateOf(app.zones[ZoneName.ambient]!.source).status,
        Status.failure,
      );
      hub.events.add(const HubLinkChanged(open: false));
      await settle();
      expect(editor.link, HubLink.lost);
    });

    test(
      'configuration changed elsewhere, no edits in progress: adopted',
      () async {
        hub.sendConfig(configJson(label: 'Changed'));
        await settle();
        expect(editor.draft!.tile('app')!.label, 'Changed');
        expect(editor.remoteConfig, isNull);
        expect(editor.dirty, isFalse);
      },
    );

    test('changed elsewhere while editing: offered, not forced', () async {
      editor.setPollSeconds(300);
      hub.sendConfig(configJson(brightness: 60));
      await settle();
      expect(editor.remoteConfig, isNotNull);
      expect(editor.draft!.pollSeconds, 300);

      editor.keepMine();
      expect(editor.saved!.wled.brightness, 60);
      expect(editor.draft!.wled.brightness, 128);
      expect(editor.dirty, isTrue);

      hub.sendConfig(configJson(brightness: 70));
      await settle();
      editor.loadRemote();
      expect(editor.draft!.wled.brightness, 70);
      expect(editor.dirty, isFalse);
    });

    test('our own save echoed back by the stream: nothing to offer', () async {
      editor.setPollSeconds(300);
      hub.sendConfig(editor.draft!.toJson());
      await settle();
      expect(editor.remoteConfig, isNull);
      expect(editor.dirty, isFalse);
    });
  });

  test('Hub unreachable on load', () async {
    final down = FakeHub()..reachable = false;
    final failed = EditorController(down.api());
    addTearDown(failed.dispose);
    await failed.start();
    expect(failed.loadError?.unreachable, isTrue);
    expect(failed.draft, isNull);
  });
}
