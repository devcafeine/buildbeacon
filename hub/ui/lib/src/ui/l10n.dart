// BuildBeacon UI — Outils de traduction : textes du Hub et des plugins, nombres, erreurs.
// Version 1.0 (2026-11-11)

import 'package:buildbeacon_core/buildbeacon_core.dart';
import 'package:flutter/widgets.dart';

import '../../l10n/app_localizations.dart';
import '../api/hub_api.dart';

extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);

  /// Langue de l'interface (`en`, `fr`), pour les textes venus du Hub.
  String get language => languageOf(Localizations.localeOf(this).languageCode);
}

extension LocalizedTextOf on LocalizedText {
  /// Le texte dans la langue de l'interface.
  String of(BuildContext context) => resolve(context.language);

  /// Idem, avec une majuscule (libellés du cœur : « état global »…).
  String titleOf(BuildContext context) => capitalized(of(context));
}

String capitalized(String text) =>
    text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);

/// 42.0 → « 42 », 2.5 → « 2.5 ».
String formatNumber(num value) =>
    value == value.roundToDouble() ? value.toInt().toString() : '$value';

/// Lecture d'un nombre saisi (virgule ou point décimal) ; `null` si invalide.
num? parseNumber(String text) {
  final normalized = text.trim().replaceAll(',', '.');
  return int.tryParse(normalized) ?? double.tryParse(normalized);
}

/// Message à afficher pour un échec d'appel au Hub.
String apiErrorText(BuildContext context, ApiException? error) {
  final l = context.l10n;
  if (error == null) return l.errorUnknown;
  if (error.unreachable) return l.hubUnreachable;
  if (error.message case final message?) return message.of(context);
  return l.httpError(error.status);
}
