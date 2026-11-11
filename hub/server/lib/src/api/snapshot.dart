// BuildBeacon Hub — API : photo de l'état du Hub (aperçu en direct) et description des plugins.
// Version 1.0 (2026-11-11)

import 'package:buildbeacon_core/buildbeacon_core.dart';

import '../hub.dart';

/// Ce que montre le Hub en ce moment, pour l'aperçu de l'interface : chaque
/// tuile et chaque zone (état et couleur de chaque LED), l'état de chaque
/// source, la connexion à WLED.
///
/// Les couleurs sont celles de la palette, à l'intensité de la LED, sans la
/// pulsation : l'interface anime elle-même les états listés dans `pulsing`.
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

/// Une source et son dernier état. Les réglages viennent de config.json :
/// aucun secret n'y figure.
Map<String, Object?> sourceJson(SourceConfig source, SourceState state) => {
  'type': source.type,
  'settings': source.settings,
  'label': describeSource(source),
  'status': state.status.json,
  'history': [for (final status in state.history) status.json],
  'metrics': {
    for (final MapEntry(key: id, value: metric) in state.metrics.entries)
      id: {
        'value': metric.value,
        'unit': ?metric.unit,
        'min': ?metric.min,
        'max': ?metric.max,
      },
  },
  'error': state.error?.toJson(),
  'updated_at': state.updatedAt?.toUtc().toIso8601String(),
};

/// Réglages de WLED et résultat de la dernière vérification.
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

/// Description d'un plugin pour l'interface, avec pour chaque secret le
/// seul fait qu'il soit renseigné dans l'environnement (jamais sa valeur).
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
