// BuildBeacon Hub — Hexagonal tiles and their zones.
// Version 1.4 (2026-11-12) — comments in English.

import 'package:buildbeacon_plugin_sdk/buildbeacon_plugin_sdk.dart';

import '../plugin/plugin_registry.dart';
import 'json_read.dart';
import 'zone_action.dart';

/// Light zone of a tile.
enum ZoneName {
  /// Project tile: top and bottom strips (4 non-contiguous LEDs: no gauge
  /// or history).
  ambient({
    DisplayMode.overall,
    DisplayMode.thresholds,
  }, LocalizedText({'en': 'ambient', 'fr': 'ambiance'})),

  /// Project tile: the 5 dots in the middle.
  dots({
    DisplayMode.overall,
    DisplayMode.history,
    DisplayMode.thresholds,
    DisplayMode.gauge,
  }, LocalizedText({'en': 'dots', 'fr': 'points'})),

  /// Master tile: the 3 LEDs behind the logo.
  system({
    DisplayMode.overall,
    DisplayMode.thresholds,
    DisplayMode.gauge,
  }, LocalizedText({'en': 'system', 'fr': 'système'}));

  const ZoneName(this.modes, this.label);

  /// Display modes accepted by the zone.
  final Set<DisplayMode> modes;

  /// Name shown in the UI.
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

  /// Zones present on this kind of tile.
  final Set<ZoneName> zones;

  /// Name shown in the UI.
  final LocalizedText label;
}

/// Position on the wall in axial coordinates ("pointy-top" hexagons).
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

  /// Position in the LED chain (wiring order): 0 for the master tile,
  /// 1, 2… for project tiles. Independent of [pos].
  final int chainIndex;

  /// Place on the wall.
  final HexPos pos;

  /// Action of each zone; a missing zone stays off.
  final Map<ZoneName, ZoneAction> zones;

  /// Consistency problems specific to the tile, translated. With [plugins],
  /// sources and mode compatibility are checked too.
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

  /// All zones of the tile kind are written (`null` when without action),
  /// so that the UI sees them without knowing the model.
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
