// BuildBeacon UI — Translation helpers: Hub and plugin texts, numbers, errors.
// Version 1.1 (2026-11-12) — comments in English.

import 'package:buildbeacon_core/buildbeacon_core.dart';
import 'package:flutter/widgets.dart';

import '../../l10n/app_localizations.dart';
import '../api/hub_api.dart';

extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);

  /// Interface language (`en`, `fr`), for texts coming from the Hub.
  String get language => languageOf(Localizations.localeOf(this).languageCode);
}

extension LocalizedTextOf on LocalizedText {
  /// The text in the interface language.
  String of(BuildContext context) => resolve(context.language);

  /// Same, capitalized (core labels: "overall status"…).
  String titleOf(BuildContext context) => capitalized(of(context));
}

String capitalized(String text) =>
    text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);

/// 42.0 → "42", 2.5 → "2.5".
String formatNumber(num value) =>
    value == value.roundToDouble() ? value.toInt().toString() : '$value';

/// Parses a typed number (decimal comma or point); `null` if invalid.
num? parseNumber(String text) {
  final normalized = text.trim().replaceAll(',', '.');
  return int.tryParse(normalized) ?? double.tryParse(normalized);
}

/// Message to show when a call to the Hub fails.
String apiErrorText(BuildContext context, ApiException? error) {
  final l = context.l10n;
  if (error == null) return l.errorUnknown;
  if (error.unreachable) return l.hubUnreachable;
  if (error.message case final message?) return message.of(context);
  return l.httpError(error.status);
}
