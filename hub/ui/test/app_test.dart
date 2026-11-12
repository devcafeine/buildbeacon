// BuildBeacon UI — Application tests: wall, panels, saving, languages.
// Version 1.8 (2026-11-12) — OpenSCAD model v1.6.

import 'package:buildbeacon_ui/src/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_hub.dart';

void main() {
  late FakeHub hub;

  Future<void> open(
    WidgetTester tester, {
    String language = 'fr',
    FakeHub? with_,
  }) async {
    hub = with_ ?? FakeHub();
    tester.view
      ..physicalSize = const Size(1400, 1000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      BuildBeaconApp(api: hub.api(), initialLanguage: language),
    );
    await tester.pumpAndSettle();
  }

  /// Lets the delay before validation elapse, then the Hub's response.
  Future<void> validate(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
  }

  Finder saveButton() => find.byWidgetPredicate(
    (w) =>
        w is ButtonStyleButton && w.runtimeType.toString().contains('Filled'),
  );

  bool enabled(WidgetTester tester, Finder button) =>
      tester.widget<ButtonStyleButton>(button).onPressed != null;

  testWidgets('the wall: one accessible area per tile, and "+" slots', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await open(tester);
    expect(find.semantics.byLabel('App'), findsOne);
    expect(find.semantics.byLabel('Site'), findsOne);
    expect(find.semantics.byLabel('BuildBeacon'), findsAny);
    expect(find.semantics.byLabel('Ajouter une tuile ici'), findsAtLeast(8));
    expect(find.textContaining('Touchez une tuile du mur'), findsOneWidget);
    expect(enabled(tester, saveButton()), isFalse);
    semantics.dispose();
  });

  testWidgets('selecting a tile: its panel, its source, its state', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await open(tester);
    hub.sendState(stateJson());
    await tester.pumpAndSettle();

    tester.semantics.tap(find.semantics.byLabel('App'));
    await tester.pumpAndSettle();
    expect(find.text('Ambiance'), findsOneWidget);
    expect(find.text('Points'), findsOneWidget);
    expect(find.text('GitHub Actions'), findsNWidgets(2));
    expect(find.text('acme/app'), findsNWidgets(2));
    expect(find.text('En ce moment : échec'), findsNWidgets(2));
    expect(
      find.textContaining('BB_GITHUB_TOKEN n\'est pas défini'),
      findsWidgets,
    );
    semantics.dispose();
  });

  testWidgets('edit then save', (tester) async {
    final semantics = tester.ensureSemantics();
    await open(tester);
    tester.semantics.tap(find.semantics.byLabel('App'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'App'), 'Frontend');
    await validate(tester);
    expect(find.text('Enregistrer'), findsOneWidget);
    expect(enabled(tester, saveButton()), isTrue);

    await tester.tap(saveButton());
    await tester.pumpAndSettle();
    expect(find.textContaining('Enregistré : le Hub applique'), findsOneWidget);
    expect(
      (hub.config['tiles']! as List)[1],
      containsPair('label', 'Frontend'),
    );
    expect(enabled(tester, saveButton()), isFalse);
    semantics.dispose();
  });

  testWidgets('add a tile, turn on a zone: the Hub reports the missing repo', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await open(tester);
    tester.semantics.tap(find.semantics.byLabel('Ajouter une tuile ici').first);
    await tester.pumpAndSettle();
    expect(find.text('tile-3'), findsWidgets);
    expect(find.textContaining('rang 3 dans la chaîne'), findsOneWidget);

    await tester.tap(find.byType(Switch).first);
    await validate(tester);
    expect(
      find.text('1 problème à corriger avant d\'enregistrer'),
      findsOneWidget,
    );
    expect(find.text('« Dépôt » est obligatoire'), findsOneWidget);
    expect(enabled(tester, saveButton()), isFalse);

    await tester.enterText(
      find.widgetWithText(TextField, 'Dépôt *'),
      'acme/site',
    );
    await validate(tester);
    expect(find.textContaining('problème'), findsNothing);
    expect(enabled(tester, saveButton()), isTrue);

    await tester.tap(find.text('Annuler les modifications'));
    await tester.pumpAndSettle();
    expect(find.semantics.byLabel('tile-3'), findsNothing);
    semantics.dispose();
  });

  testWidgets('chain: wiring order and LED count of WLED', (tester) async {
    await open(tester);
    hub.sendState(stateJson());
    await tester.tap(find.text('Chaîne'));
    await tester.pumpAndSettle();
    expect(find.text('LED 0 à 2'), findsOneWidget);
    expect(find.text('LED 3 à 11'), findsOneWidget);
    expect(find.text('LED 12 à 20'), findsOneWidget);
    expect(find.text('WLED est réglé sur 21 LED : correct.'), findsOneWidget);
  });

  testWidgets('settings: brightness above 50% flagged', (tester) async {
    await open(tester);
    await tester.tap(find.text('Réglages'));
    await tester.pumpAndSettle();
    expect(find.text('Luminosité : 50 % (128/255)'), findsOneWidget);
    expect(find.textContaining('peuvent scintiller'), findsNothing);

    await tester.drag(find.byType(Slider), const Offset(120, 0));
    await tester.pumpAndSettle();
    expect(find.textContaining('peuvent scintiller'), findsOneWidget);
    expect(find.text('Annuler les modifications'), findsOneWidget);
  });

  testWidgets('Hub protected by a token: asked for on save', (tester) async {
    await open(tester, with_: FakeHub(apiToken: 'secret'));
    await tester.tap(find.text('Réglages'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '60'), '120');
    await validate(tester);

    await tester.tap(saveButton());
    await tester.pumpAndSettle();
    expect(find.text('Jeton de l\'API'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Jeton'), 'secret');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(hub.config['poll_seconds'], 120);
  });

  testWidgets('"3D printing" tab: parts of the wall', (tester) async {
    await open(tester);
    // The tab bar scrolls when the labels do not fit (wide test font).
    await tester.ensureVisible(find.text('Impression 3D'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Impression 3D'));
    await tester.pumpAndSettle();
    expect(
      find.text("Coque avec le logo, plaque arrière pour l'ESP32"),
      findsOneWidget,
    );
    // Outside a browser (tests), no download: a clear message.
    final download = find.text('Télécharger buildbeacon_tile_v1.6.json');
    await tester.ensureVisible(download);
    await tester.pumpAndSettle();
    await tester.tap(download);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Téléchargement impossible ici'),
      findsOneWidget,
    );
  });

  testWidgets('in English', (tester) async {
    await open(tester, language: 'en');
    expect(find.text('Tile'), findsOneWidget);
    expect(find.text('Chain'), findsOneWidget);
    expect(find.text('Saved'), findsOneWidget);
    expect(find.textContaining('Select a tile on the wall'), findsOneWidget);
  });

  testWidgets('Hub unreachable: message and "Retry"', (tester) async {
    await open(tester, with_: FakeHub()..reachable = false);
    expect(
      find.text('Impossible de charger la configuration du Hub'),
      findsOneWidget,
    );
    hub.reachable = true;
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(find.text('Tuile'), findsOneWidget);
  });
}
