// BuildBeacon UI — Tests: draft, chain, saving, changes coming from the Hub.
// Version 1.1 (2026-11-12) — comments in English.

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

  test('chargement : configuration et plugins, rien à enregistrer', () {
    expect(editor.loadError, isNull);
    expect(editor.draft!.tiles, hasLength(3));
    expect(editor.plugins.map((p) => p.type), ['github', 'printer']);
    expect(editor.dirty, isFalse);
  });

  group('tuiles', () {
    test('ajout : en bout de chaîne, sélectionnée', () {
      final id = editor.addTile(const HexPos(1, 0));
      expect(id, 'tile-3');
      expect(editor.selectedTileId, 'tile-3');
      expect(chain()['tile-3'], 3);
      expect(editor.dirty, isTrue);
      expect(editor.addTile(const HexPos(1, 0)), isNull, reason: 'case prise');
    });

    test('retrait : les suivantes remontent ; annulation possible', () {
      final before = editor.removeTile('app');
      expect(chain(), {'master': 0, 'site': 1});
      editor.restore(before!);
      expect(editor.dirty, isFalse);
      expect(editor.removeTile('master'), isNull, reason: 'la master reste');
    });

    test('déplacement : vers une case libre, ou échange de places', () {
      editor.moveTile('site', const HexPos(2, 0));
      expect(editor.draft!.tile('site')!.pos, const HexPos(2, 0));
      editor.moveTile('site', const HexPos(0, 0));
      expect(editor.draft!.tile('site')!.pos, const HexPos(0, 0));
      expect(editor.draft!.tile('app')!.pos, const HexPos(2, 0));
    });

    test('ordre de la chaîne', () {
      editor.addTile(const HexPos(1, 0));
      editor.moveInChain(2, 0);
      expect(chain(), {'master': 0, 'app': 2, 'site': 3, 'tile-3': 1});
    });

    test('identifiant : vide ou déjà pris refusé ; la sélection suit', () {
      editor.select('app');
      expect(editor.renameTile('app', 'site'), isFalse);
      expect(editor.renameTile('app', '  '), isFalse);
      expect(editor.renameTile('app', ' frontend '), isTrue);
      expect(editor.selectedTileId, 'frontend');
      expect(editor.draft!.tile('frontend'), isNotNull);
    });

    test(
      'zone allumée : même source que l\'autre zone, historique sur les points',
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

  group('validation et enregistrement', () {
    test('problèmes signalés par le Hub au fil de la saisie', () async {
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

    test('enregistré : le brouillon devient la configuration du Hub', () async {
      editor.updateTile('app', (t) => t.copyWith(label: 'Frontend'));
      expect(await editor.save(), SaveResult.saved);
      expect(editor.dirty, isFalse);
      expect(hub.requests, contains('PUT /api/config'));
      expect(
        (hub.config['tiles']! as List)[1],
        containsPair('label', 'Frontend'),
      );
    });

    test('refusé (422) : problèmes affichés, brouillon gardé', () async {
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

    test('jeton exigé', () async {
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

  group('événements du Hub', () {
    test('état en direct', () async {
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
      'configuration changée ailleurs, sans modification en cours : adoptée',
      () async {
        hub.sendConfig(configJson(label: 'Changed'));
        await settle();
        expect(editor.draft!.tile('app')!.label, 'Changed');
        expect(editor.remoteConfig, isNull);
        expect(editor.dirty, isFalse);
      },
    );

    test(
      'changée ailleurs pendant la saisie : proposée, pas imposée',
      () async {
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
      },
    );

    test(
      'notre propre enregistrement revenu par le flux : rien à proposer',
      () async {
        editor.setPollSeconds(300);
        hub.sendConfig(editor.draft!.toJson());
        await settle();
        expect(editor.remoteConfig, isNull);
        expect(editor.dirty, isFalse);
      },
    );
  });

  test('Hub injoignable au chargement', () async {
    final down = FakeHub()..reachable = false;
    final failed = EditorController(down.api());
    addTearDown(failed.dispose);
    await failed.start();
    expect(failed.loadError?.unreachable, isTrue);
    expect(failed.draft, isNull);
  });
}
