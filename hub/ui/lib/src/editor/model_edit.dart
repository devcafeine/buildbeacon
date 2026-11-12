// BuildBeacon UI — Modified copies of the model (the core model is immutable).
// Version 1.1 (2026-11-12) — comments in English.

import 'dart:convert';

import 'package:buildbeacon_core/buildbeacon_core.dart';

/// Default value of the parameters that accept `null`: "leave unchanged".
const Object _keep = Object();

extension ConfigEdit on Config {
  Config copyWith({
    WledConfig? wled,
    int? pollSeconds,
    Palette? palette,
    List<Tile>? tiles,
  }) => Config(
    wled: wled ?? this.wled,
    pollSeconds: pollSeconds ?? this.pollSeconds,
    palette: palette ?? this.palette,
    tiles: tiles ?? this.tiles,
  );

  Tile? tile(String id) {
    for (final tile in tiles) {
      if (tile.id == id) return tile;
    }
    return null;
  }

  Tile? tileAt(HexPos pos) {
    for (final tile in tiles) {
      if (tile.pos == pos) return tile;
    }
    return null;
  }

  /// Project tiles in chain order (wiring order).
  List<Tile> get projectTiles =>
      tiles.where((t) => t.kind == TileKind.project).toList()
        ..sort((a, b) => a.chainIndex.compareTo(b.chainIndex));

  /// Same JSON content (same config.json once saved).
  bool sameAs(Config? other) =>
      other != null && jsonEncode(toJson()) == jsonEncode(other.toJson());
}

extension WledEdit on WledConfig {
  WledConfig copyWith({
    String? host,
    int? port,
    int? ddpPort,
    int? brightness,
  }) => WledConfig(
    host: host ?? this.host,
    port: port ?? this.port,
    ddpPort: ddpPort ?? this.ddpPort,
    brightness: brightness ?? this.brightness,
  );
}

extension TileEdit on Tile {
  Tile copyWith({
    String? id,
    String? label,
    int? chainIndex,
    HexPos? pos,
    Map<ZoneName, ZoneAction>? zones,
  }) => Tile(
    id: id ?? this.id,
    label: label ?? this.label,
    kind: kind,
    chainIndex: chainIndex ?? this.chainIndex,
    pos: pos ?? this.pos,
    zones: zones ?? this.zones,
  );

  /// The tile with [action] in [zone] (`null` = zone turned off).
  Tile withZone(ZoneName zone, ZoneAction? action) {
    final changed = {...zones}..remove(zone);
    if (action != null) changed[zone] = action;
    return copyWith(zones: changed);
  }

  /// Displayed name: the label, otherwise the id.
  String get displayName => label.trim().isEmpty ? id : label;
}

extension ZoneActionEdit on ZoneAction {
  ZoneAction copyWith({
    SourceConfig? source,
    DisplayMode? mode,
    Object? metric = _keep,
    Thresholds? thresholds,
    Object? min = _keep,
    Object? max = _keep,
  }) => ZoneAction(
    source: source ?? this.source,
    mode: mode ?? this.mode,
    metric: identical(metric, _keep) ? this.metric : metric as String?,
    thresholds: thresholds ?? this.thresholds,
    min: identical(min, _keep) ? this.min : min as num?,
    max: identical(max, _keep) ? this.max : max as num?,
  );
}

extension ThresholdsEdit on Thresholds {
  Thresholds copyWith({
    Object? warning = _keep,
    Object? failure = _keep,
    AlertDirection? direction,
  }) => Thresholds(
    warning: identical(warning, _keep) ? this.warning : warning as num?,
    failure: identical(failure, _keep) ? this.failure : failure as num?,
    direction: direction ?? this.direction,
  );
}

extension SourceConfigEdit on SourceConfig {
  /// Same source with setting [id] changed (`null` = removed).
  SourceConfig withSetting(String id, Object? value) => SourceConfig(
    type: type,
    settings: {
      for (final MapEntry(:key, value: v) in settings.entries)
        if (key != id) key: v,
      id: ?value,
    },
  );
}

extension PaletteEdit on Palette {
  Palette withColor(Status status, Rgb color) =>
      Palette({for (final s in Status.values) s: this[s], status: color});
}
