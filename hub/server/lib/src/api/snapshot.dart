// BuildBeacon Hub — API: snapshot of the Hub state (live preview) and plugin descriptions.
// Version 1.2 (2026-11-12) — comments in English.

import 'package:buildbeacon_core/buildbeacon_core.dart';

import '../hub.dart';

/// What the Hub is showing right now, for the interface preview: each tile
/// and each zone (status and color of each LED), the state of each source,
/// the connection to WLED.
///
/// The colors are the palette's, at the LED's intensity, without the
/// pulsing: the interface itself animates the statuses listed in `pulsing`.
Map<String, Object?> hubSnapshot(Hub hub) {
  final config = hub.config;
  final states = hub.states;
  final identifying = hub.identifying;
  final palette = config.palette;

  Map<String, Object?> led(LedOutput output) => {
    'status': output.status.json,
    'intensity': double.parse(output.intensity.toStringAsFixed(2)),
    'color': palette[output.status].scaled(output.intensity).toHex(),
  };

  Map<String, Object?>? zone(Tile tile, ZoneName name) {
    final action = tile.zones[name];
    if (action == null) return null;
    final state = states[action.source.key] ?? SourceState.unknown;
    final validRank = tile.kind == TileKind.master || tile.chainIndex >= 1;
    final count = validRank
        ? LedLayout.zoneIndices(tile.kind, tile.chainIndex, name).length
        : 0;
    return {
      'mode': action.mode.json,
      'source': action.source.key,
      'leds': [
        for (final output in FrameRenderer.zoneOutputs(action, state, count))
          led(output),
      ],
    };
  }

  final sources = <String, SourceConfig>{
    for (final tile in config.tiles)
      for (final action in tile.zones.values) action.source.key: action.source,
  };

  return {
    'generated_at': DateTime.now().toUtc().toIso8601String(),
    'led_count': config.ledCount,
    'palette': palette.toJson(),
    'pulsing': [
      for (final status in Status.values)
        if (status.pulses) status.json,
    ],
    'tiles': [
      for (final tile in config.tiles)
        {
          'id': tile.id,
          'label': tile.label,
          'kind': tile.kind.name,
          'chain_index': tile.chainIndex,
          'pos': tile.pos.toJson(),
          'identifying': identifying.contains(tile.id),
          'zones': {
            for (final name in tile.kind.zones) name.name: zone(tile, name),
          },
        },
    ],
    'sources': {
      for (final MapEntry(:key, value: source) in sources.entries)
        key: sourceJson(source, states[key] ?? SourceState.unknown),
    },
    'wled': wledJson(config, hub.wled),
  };
}

/// A source and its latest state. The settings come from config.json: no
/// secret appears in them.
Map<String, Object?> sourceJson(SourceConfig source, SourceState state) => {
  'type': source.type,
  'settings': source.settings,
  'label': describeSource(source),
  ...SourceStateJson.encode(state),
};

/// WLED settings and result of the last check.
Map<String, Object?> wledJson(Config config, WledStatus? status) {
  final info = status?.info;
  return {
    ...config.wled.toJson(),
    'checked_at': status?.checkedAt.toUtc().toIso8601String(),
    'info': info == null
        ? null
        : {
            'version': info.version,
            'name': info.name,
            'led_count': info.ledCount,
          },
    'led_count_matches': info == null ? null : info.ledCount == config.ledCount,
    'error': status?.error,
  };
}

/// Description of a plugin for the interface, with, for each secret, only
/// whether it is set in the environment (never its value).
Map<String, Object?> pluginJson(
  SourcePlugin plugin,
  Map<String, String> environment,
) {
  final described = plugin.describe();
  return {
    ...described,
    'secrets': [
      for (final secret in plugin.secrets)
        {...secret.toJson(), 'configured': environment.containsKey(secret.env)},
    ],
  };
}
