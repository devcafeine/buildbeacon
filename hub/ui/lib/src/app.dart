// BuildBeacon UI — Application : thème, langues (anglais, français), page principale.
// Version 1.0 (2026-11-11)

import 'package:buildbeacon_core/buildbeacon_core.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'api/hub_api.dart';
import 'editor/editor_controller.dart';
import 'platform/preferences.dart';
import 'ui/home_page.dart';

class BuildBeaconApp extends StatefulWidget {
  const BuildBeaconApp({
    super.key,
    required this.api,
    this.preferences,
    this.initialLanguage,
  });

  final HubApi api;
  final Preferences? preferences;

  /// Langue imposée (`?lang=fr` dans l'adresse) ; sinon celle choisie dans
  /// le menu, sinon celle du navigateur.
  final String? initialLanguage;

  @override
  State<BuildBeaconApp> createState() => _BuildBeaconAppState();
}

class _BuildBeaconAppState extends State<BuildBeaconApp> {
  static const _languageKey = 'language';

  late final Preferences _preferences = widget.preferences ?? Preferences();
  late final EditorController _editor = EditorController(widget.api);
  late final LanguageChoice _language = LanguageChoice(
    _validLanguage(widget.initialLanguage) ??
        _validLanguage(_preferences.read(_languageKey)),
  );

  static String? _validLanguage(String? code) =>
      code != null && supportedLanguages.contains(code) ? code : null;

  @override
  void initState() {
    super.initState();
    _editor.start();
    _language.addListener(
      () => _preferences.write(_languageKey, _language.value),
    );
  }

  @override
  void dispose() {
    _editor.dispose();
    _language.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: _language,
    builder: (context, language, _) => MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      locale: language == null ? null : Locale(language),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      // Langue du navigateur non traduite : anglais.
      localeResolutionCallback: (locale, supported) => supported.firstWhere(
        (s) => s.languageCode == locale?.languageCode,
        orElse: () => const Locale(fallbackLanguage),
      ),
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: HomePage(editor: _editor, language: _language),
    ),
  );
}

/// Thème Material 3 sur la couleur d'accent du projet (pétrole).
ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF0A6B75),
    brightness: brightness,
  );
  return ThemeData(
    colorScheme: scheme,
    fontFamily: 'Roboto',
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
      isDense: true,
    ),
  );
}
