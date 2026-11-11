// BuildBeacon Hub — Configuration complète (contenu de config.json).
// Version 1.2 (2026-11-11) — messages de validation et erreurs de format traduits.

import 'package:buildbeacon_plugin_sdk/buildbeacon_plugin_sdk.dart';

import '../plugin/plugin_registry.dart';
import 'json_read.dart';
import 'led_layout.dart';
import 'palette.dart';
import 'tile.dart';

/// Connexion au contrôleur WLED.
final class WledConfig {
  const WledConfig({
    this.host = 'buildbeacon.local',
    this.port = 80,
    this.ddpPort = 4048,
    this.brightness = 128,
  });

  factory WledConfig.fromJson(Map<String, Object?> json) => WledConfig(
    host: json.optionalField<String>('host') ?? 'buildbeacon.local',
    port: json.optionalField<int>('port') ?? 80,
    ddpPort: json.optionalField<int>('ddp_port') ?? 4048,
    brightness: json.optionalField<int>('brightness') ?? 128,
  );

  /// Nom mDNS (`buildbeacon.local`) ou adresse IP.
  final String host;

  /// Port HTTP de l'API JSON de WLED.
  final int port;

  /// Port UDP du flux temps réel DDP (4048 chez WLED ; modifiable pour le simulateur).
  final int ddpPort;

  /// Luminosité globale 0 – 255. 128 (50 %) par défaut : au-delà, scintillement constaté.
  final int brightness;

  List<LocalizedText> validate() => [
    if (host.trim().isEmpty)
      const LocalizedText({
        'en': 'WLED: empty address (.local name or IP expected)',
        'fr': 'WLED : adresse vide (nom .local ou IP attendu)',
      }),
    if (port < 1 || port > 65535)
      LocalizedText.build(
        (l) => tr(
          l,
          en: 'WLED: invalid HTTP port ($port)',
          fr: 'WLED : port HTTP invalide ($port)',
        ),
      ),
    if (ddpPort < 1 || ddpPort > 65535)
      LocalizedText.build(
        (l) => tr(
          l,
          en: 'WLED: invalid DDP port ($ddpPort)',
          fr: 'WLED : port DDP invalide ($ddpPort)',
        ),
      ),
    if (brightness < 0 || brightness > 255)
      LocalizedText.build(
        (l) => tr(
          l,
          en: 'WLED: brightness outside 0 – 255 ($brightness)',
          fr: 'WLED : luminosité hors de 0 – 255 ($brightness)',
        ),
      ),
  ];

  Map<String, Object?> toJson() => {
    'host': host,
    'port': port,
    'ddp_port': ddpPort,
    'brightness': brightness,
  };
}

final class Config {
  Config({
    this.wled = const WledConfig(),
    this.pollSeconds = defaultPollSeconds,
    Palette? palette,
    List<Tile> tiles = const [],
  }) : palette = palette ?? Palette(),
       tiles = List.unmodifiable(tiles);

  /// Configuration de départ : la master seule, sans action.
  factory Config.initial() => Config(
    tiles: [
      Tile(
        id: 'master',
        label: 'BuildBeacon',
        kind: TileKind.master,
        chainIndex: 0,
        pos: const HexPos(0, 0),
      ),
    ],
  );

  factory Config.fromJson(Map<String, Object?> json) {
    final version = json.optionalField<int>('version') ?? schemaVersion;
    if (version > schemaVersion) {
      throw LocalizedFormatException(
        LocalizedText.build(
          (l) => tr(
            l,
            en:
                'config.json is version $version; this Hub only reads '
                'version $schemaVersion or earlier',
            fr:
                'config.json est en version $version ; ce Hub ne lit que '
                'la version $schemaVersion ou antérieure',
          ),
        ),
      );
    }
    final tiles = json.optionalField<List<Object?>>('tiles') ?? const [];
    return Config(
      wled: WledConfig.fromJson(json.objectField('wled')),
      pollSeconds:
          json.optionalField<int>('poll_seconds') ?? defaultPollSeconds,
      palette: Palette.fromJson(json.objectField('palette')),
      tiles: [for (final (i, tile) in tiles.indexed) _tileFromJson(i, tile)],
    );
  }

  /// Version du format de `config.json` (migrations futures).
  static const schemaVersion = 1;
  static const defaultPollSeconds = 30;
  static const minPollSeconds = 10;

  final WledConfig wled;
  final int pollSeconds;
  final Palette palette;
  final List<Tile> tiles;

  /// Nombre de LED de la chaîne décrite.
  int get ledCount => LedLayout.ledCount(tiles);

  /// Liste des problèmes, traduits ; vide si la config est utilisable. Sans
  /// [plugins], les réglages des sources ne sont pas vérifiés.
  List<LocalizedText> validate({PluginRegistry? plugins}) => [
    ...wled.validate(),
    if (pollSeconds < minPollSeconds)
      LocalizedText.build(
        (l) => tr(
          l,
          en:
              'Polling interval too short ($pollSeconds s, '
              'minimum $minPollSeconds s)',
          fr:
              'Intervalle de scrutation trop court ($pollSeconds s, '
              'minimum $minPollSeconds s)',
        ),
      ),
    if (tiles.where((t) => t.kind == TileKind.master).length case final n
        when n != 1)
      LocalizedText.build(
        (l) => tr(
          l,
          en: 'Exactly one master tile is required ($n found)',
          fr: 'Il faut exactement une tuile master ($n trouvée(s))',
        ),
      ),
    ..._duplicates(
      tiles.map((t) => t.id),
      (id) => LocalizedText.build(
        (l) => tr(
          l,
          en: 'Duplicate tile identifier: "$id"',
          fr: 'Identifiant de tuile en double : « $id »',
        ),
      ),
    ),
    ..._duplicates(
      tiles.map((t) => t.chainIndex),
      (rank) => LocalizedText.build(
        (l) => tr(
          l,
          en: 'Two tiles at the same chain position: $rank',
          fr: 'Deux tuiles au même rang dans la chaîne : $rank',
        ),
      ),
    ),
    ..._duplicates(
      tiles.map((t) => t.pos),
      (pos) => LocalizedText.build(
        (l) => tr(
          l,
          en: 'Two tiles at the same place on the wall: $pos',
          fr: 'Deux tuiles à la même place au mur : $pos',
        ),
      ),
    ),
    for (final tile in tiles) ...tile.validate(plugins: plugins),
  ];

  Map<String, Object?> toJson() => {
    'version': schemaVersion,
    'wled': wled.toJson(),
    'poll_seconds': pollSeconds,
    'palette': palette.toJson(),
    'tiles': [for (final tile in tiles) tile.toJson()],
  };

  static Tile _tileFromJson(int index, Object? json) {
    final number = index + 1;
    LocalizedFormatException prefixed(LocalizedText message) =>
        LocalizedFormatException(
          LocalizedText.build(
            (l) => tr(
              l,
              en: 'Tile #$number: ${message.resolve(l)}',
              fr: 'Tuile n° $number : ${message.resolve(l)}',
            ),
          ),
        );

    if (json is! Map<String, Object?>) {
      throw prefixed(
        const LocalizedText({'en': 'object expected', 'fr': 'objet attendu'}),
      );
    }
    try {
      return Tile.fromJson(json);
    } on LocalizedFormatException catch (e) {
      throw prefixed(e.text);
    } on FormatException catch (e) {
      throw prefixed(LocalizedText.same(e.message));
    }
  }

  /// Un message par valeur répétée (une seule fois, même si elle apparaît 3 fois).
  static List<LocalizedText> _duplicates<T>(
    Iterable<T> values,
    LocalizedText Function(T value) message,
  ) {
    final seen = <T>{};
    final reported = <T>{};
    return [
      for (final value in values)
        if (!seen.add(value) && reported.add(value)) message(value),
    ];
  }
}
