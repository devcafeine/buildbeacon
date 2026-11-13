// BuildBeacon UI — Tests: 3D printing parts and OpenSCAD parameter sets.
// Version 1.6 (2026-11-13) — OpenSCAD model v1.7.

import 'dart:convert';
import 'dart:io';

import 'package:buildbeacon_core/buildbeacon_core.dart';
import 'package:buildbeacon_ui/l10n/app_localizations.dart';
import 'package:buildbeacon_ui/src/editor/editor_controller.dart';
import 'package:buildbeacon_ui/src/editor/print_plan.dart';
import 'package:buildbeacon_ui/src/ui/print_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_hub.dart';

void main() {
  // Master at (0, 1), App at (0, 0), Site at (1, 1): the user's staircase.
  final config = Config.fromJson(configJson());

  group('parts of the wall', () {
    test('a shell per tile, the master back plate, one back plate for the '
        'project tiles', () {
      final plan = PrintPlan.of(config);
      expect(plan.tiles.map((t) => t.id), ['master', 'app', 'site']);
      expect(plan.parts.map((p) => p.set), [
        'master-tile',
        'master-back',
        'app-tile',
        'site-tile',
        'project-back',
        'links',
      ]);
      expect(plan.parts.map((p) => p.copies), [1, 1, 1, 1, 2, 1]);
    });

    test('dog bones: one per side shared by two tiles', () {
      expect(PrintPlan.of(config).links, 2);
      expect(PrintPlan.sharedSides(const [HexPos(0, 0)]), 0);
      expect(
        PrintPlan.sharedSides(const [HexPos(0, 0), HexPos(1, 0), HexPos(2, 0)]),
        2,
      );
      // Three tiles touching each other two by two.
      expect(
        PrintPlan.sharedSides(const [HexPos(0, 0), HexPos(1, 0), HexPos(0, 1)]),
        3,
      );
    });

    test('a single tile: no dog bone set', () {
      final plan = PrintPlan.of(Config.initial());
      expect(plan.links, 0);
      expect(plan.parts.map((p) => p.part), ['tile', 'back']);
    });
  });

  group('OpenSCAD parameter sets', () {
    test('file format of the Customizer: every value as text', () {
      final json =
          jsonDecode(PrintPlan.of(config).toParameterSets())
              as Map<String, Object?>;
      expect(json['fileFormatVersion'], '1');
      final sets = json['parameterSets']! as Map<String, Object?>;
      expect(sets['app-tile'], {
        'part': 'tile',
        'label': 'App',
        'master': 'false',
        'master_logo': 'false',
      });
      expect(sets['master-tile'], {
        'part': 'tile',
        'label': 'BuildBeacon',
        'master': 'true',
        'master_logo': 'true',
      });
      expect(sets['master-back'], {'part': 'back', 'master': 'true'});
      expect(sets['project-back'], {'part': 'back', 'master': 'false'});
      expect(sets['links'], {'part': 'links', 'link_count': '2'});
    });

    test('one command per part', () {
      final commands = PrintPlan.of(config).commands();
      expect(commands, hasLength(6));
      expect(
        commands[2],
        'openscad -p buildbeacon_tile_v1.7.json -P app-tile '
        '-o app-tile.stl buildbeacon_tile_v1.7.scad',
      );
    });

    test('identifiers turned into set and file names, without clashes', () {
      final tiles = [
        for (final (i, id) in ['Mon Projet!', 'mon-projet', '***'].indexed)
          Tile(
            id: id,
            label: '',
            kind: TileKind.project,
            chainIndex: i + 1,
            pos: HexPos(i * 3, 0),
          ),
      ];
      final sets = PrintPlan.of(Config(tiles: tiles)).parts.map((p) => p.set);
      expect(sets, [
        'mon-projet-tile',
        'mon-projet-2-tile',
        'tile-tile',
        'project-back',
      ]);
      // The engraved name is the identifier when there is no label.
      expect(
        PrintPlan.of(Config(tiles: tiles)).parts.first.parameters['label'],
        'Mon Projet!',
      );
    });
  });

  test(
    'contract with the model of hardware/cad: same file, same parameters',
    () {
      final model = File('../../hardware/cad/$cadModelFile');
      expect(model.existsSync(), isTrue, reason: 'model renamed or moved');
      final source = model.readAsStringSync();
      for (final name in ['label', 'master', 'master_logo', 'link_count']) {
        expect(source, matches(RegExp('^$name\\s*=', multiLine: true)));
      }
      final parts = RegExp(
        r'^part\s*=.*\[(.*)\]',
        multiLine: true,
      ).firstMatch(source)![1]!.split(',').map((p) => p.trim());
      expect(parts, containsAll(['tile', 'back', 'links', 'link_test']));
    },
  );

  testWidgets('panel: parts listed, file downloaded, commands copied', (
    tester,
  ) async {
    final editor = EditorController(FakeHub().api());
    await editor.start();
    final saved = <(String, String, String)>[];
    tester.view
      ..physicalSize = const Size(600, 1600)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: PrintPanel(
            editor: editor,
            saveFile: (name, text, type) {
              saved.add((name, text, type));
              return true;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Coque avec le nom'), findsNWidgets(2));
    expect(
      find.text(
        '2 plaques arrière pour les tuiles projet : toutes identiques, un '
        'seul fichier à imprimer 2 fois',
      ),
      findsOneWidget,
    );
    expect(
      find.text("Coque avec le logo, plaque arrière pour l'ESP32"),
      findsOneWidget,
    );
    expect(
      find.text('2 os de chien, un par côté commun à deux tuiles'),
      findsOneWidget,
    );

    await tester.tap(find.text('Télécharger buildbeacon_tile_v1.7.json'));
    expect(saved.single.$1, 'buildbeacon_tile_v1.7.json');
    expect(saved.single.$3, 'application/json');
    expect(jsonDecode(saved.single.$2), contains('parameterSets'));

    await tester.tap(find.text('Copier les commandes'));
    await tester.pumpAndSettle();
    expect(copied, startsWith('openscad -p buildbeacon_tile_v1.7.json'));
    expect(find.text('Commandes copiées.'), findsOneWidget);

    // Stops the live stream (and its timers) before the end of the test.
    await tester.pumpWidget(const SizedBox());
    editor.dispose();
  });
}
