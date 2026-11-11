// BuildBeacon Hub — Tuiles hexagonales et leurs zones.
// Version 1.3 (2026-11-11) — identifiants en anglais (ambient, dots, system, project), libellés et messages traduits.

import 'package:buildbeacon_plugin_sdk/buildbeacon_plugin_sdk.dart';

import '../plugin/plugin_registry.dart';
import 'json_read.dart';
import 'zone_action.dart';

/// Zone lumineuse d'une tuile.
enum ZoneName {
  /// Tuile projet : rubans du haut et du bas (4 LED, non contiguës : pas de
  /// jauge ni d'historique).
  ambient({
    DisplayMode.overall,
    DisplayMode.thresholds,
  }, LocalizedText({'en': 'ambient', 'fr': 'ambiance'})),

  /// Tuile projet : les 5 points du milieu.
  dots({
    DisplayMode.overall,
    DisplayMode.history,
    DisplayMode.thresholds,
    DisplayMode.gauge,
  }, LocalizedText({'en': 'dots', 'fr': 'points'})),

  /// Tuile master : les 3 LED derrière le logo.
  system({
    DisplayMode.overall,
    DisplayMode.thresholds,
    DisplayMode.gauge,
  }, LocalizedText({'en': 'system', 'fr': 'système'}));

  const ZoneName(this.modes, this.label);

  /// Modes d'affichage acceptés par la zone.
  final Set<DisplayMode> modes;

  /// Nom affiché dans l'interface.
  final LocalizedText label;

  static ZoneName? tryParse(String name) => values.asNameMap()[name];
}

enum TileKind {
  master({ZoneName.system}, LocalizedText({'en': 'master', 'fr': 'master'})),
  project({
    ZoneName.ambient,
    ZoneName.dots,
  }, LocalizedText({'en': 'project', 'fr': 'projet'}));

  const TileKind(this.zones, this.label);

  /// Zones présentes sur ce type de tuile.
  final Set<ZoneName> zones;

  /// Nom affiché dans l'interface.
  final LocalizedText label;
}

/// Position sur le mur en coordonnées axiales (hexagones « pointe en haut »).
final class HexPos {
  const HexPos(this.q, this.r);

  factory HexPos.fromJson(Map<String, Object?> json) =>
      HexPos(json.field<int>('q'), json.field<int>('r'));

  final int q;
  final int r;

  Map<String, Object?> toJson() => {'q': q, 'r': r};

  @override
  bool operator ==(Object other) =>
      other is HexPos && other.q == q && other.r == r;

  @override
  int get hashCode => Object.hash(q, r);

  @override
  String toString() => '($q, $r)';
}

final class Tile {
  Tile({
    required this.id,
    required this.label,
    required this.kind,
    required this.chainIndex,
    required this.pos,
    Map<ZoneName, ZoneAction> zones = const {},
  }) : zones = Map.unmodifiable(zones);

  factory Tile.fromJson(Map<String, Object?> json) {
    final kindName = json.field<String>('kind');
    final zones = <ZoneName, ZoneAction>{};
    for (final MapEntry(:key, :value) in json.objectField('zones').entries) {
      final zone =
          ZoneName.tryParse(key) ??
          (throw LocalizedFormatException(
            LocalizedText.build(
              (l) =>
                  tr(l, en: 'Unknown zone: $key', fr: 'Zone inconnue : $key'),
            ),
          ));
      switch (value) {
        case null:
          continue;
        case final Map<String, Object?> action:
          zones[zone] = ZoneAction.fromJson(action);
        default:
          throw LocalizedFormatException(
            LocalizedText.build(
              (l) => tr(
                l,
                en: 'Zone "$key": invalid action',
                fr: 'Zone « $key » : action invalide',
              ),
            ),
          );
      }
    }
    return Tile(
      id: json.field<String>('id'),
      label: json.optionalField<String>('label') ?? '',
      kind:
          TileKind.values.asNameMap()[kindName] ??
          (throw LocalizedFormatException(
            LocalizedText.build(
              (l) => tr(
                l,
                en: 'Unknown tile kind: $kindName',
                fr: 'Type de tuile inconnu : $kindName',
              ),
            ),
          )),
      chainIndex: json.field<int>('chain_index'),
      pos: HexPos.fromJson(json.field<Map<String, Object?>>('pos')),
      zones: zones,
    );
  }

  final String id;
  final String label;
  final TileKind kind;

  /// Rang dans la chaîne de LED (ordre de câblage) : 0 pour la master,
  /// 1, 2… pour les tuiles projet. Indépendant de [pos].
  final int chainIndex;

  /// Place sur le mur.
  final HexPos pos;

  /// Action de chaque zone ; une zone absente reste éteinte.
  final Map<ZoneName, ZoneAction> zones;

  /// Problèmes de cohérence propres à la tuile, traduits. Avec [plugins],
  /// les sources et la compatibilité des modes sont aussi vérifiées.
  List<LocalizedText> validate({PluginRegistry? plugins}) {
    final issues = <LocalizedText>[
      if (id.trim().isEmpty)
        const LocalizedText({
          'en': 'empty identifier',
          'fr': 'identifiant vide',
        }),
      if (kind == TileKind.master && chainIndex != 0)
        const LocalizedText({
          'en': 'the master is always first in the chain (position 0)',
          'fr': 'la master est toujours en tête de chaîne (position 0)',
        }),
      if (kind == TileKind.project && chainIndex < 1)
        const LocalizedText({
          'en': 'a project tile has a chain position ≥ 1',
          'fr': 'une tuile projet a une position de chaîne ≥ 1',
        }),
      for (final MapEntry(key: zone, value: action) in zones.entries) ...[
        if (!kind.zones.contains(zone))
          LocalizedText.build(
            (l) => tr(
              l,
              en:
                  'no ${zone.label.resolve(l)} zone on a '
                  '${kind.label.resolve(l)} tile',
              fr:
                  'pas de zone « ${zone.label.resolve(l)} » sur une tuile '
                  '${kind.label.resolve(l)}',
            ),
          )
        else if (!zone.modes.contains(action.mode))
          LocalizedText.build(
            (l) => tr(
              l,
              en:
                  '"${action.mode.label.resolve(l)}" mode is not available '
                  'in the ${zone.label.resolve(l)} zone',
              fr:
                  'mode « ${action.mode.label.resolve(l)} » impossible dans '
                  'la zone ${zone.label.resolve(l)}',
            ),
          ),
        for (final issue in [
          ...action.validate(),
          ...?plugins?.validateAction(action),
        ])
          LocalizedText.build(
            (l) => tr(
              l,
              en: '${zone.label.resolve(l)}: ${issue.resolve(l)}',
              fr: '${zone.label.resolve(l)} : ${issue.resolve(l)}',
            ),
          ),
      ],
    ];
    final name = label.isEmpty ? id : label;
    return [
      for (final issue in issues)
        LocalizedText.build(
          (l) => tr(
            l,
            en: 'Tile "$name": ${issue.resolve(l)}',
            fr: 'Tuile « $name » : ${issue.resolve(l)}',
          ),
        ),
    ];
  }

  /// Toutes les zones du type de tuile sont écrites (`null` si sans action),
  /// pour que l'interface les voie sans connaître le modèle.
  Map<String, Object?> toJson() => {
    'id': id,
    'label': label,
    'kind': kind.name,
    'chain_index': chainIndex,
    'pos': pos.toJson(),
    'zones': {
      for (final zone in {...kind.zones, ...zones.keys})
        zone.name: zones[zone]?.toJson(),
    },
  };
}
