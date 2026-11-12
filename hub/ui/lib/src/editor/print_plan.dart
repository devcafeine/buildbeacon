// BuildBeacon UI — 3D printing: parts of the wall and OpenSCAD parameter sets.
// Version 1.4 (2026-11-12) — OpenSCAD model v1.5.

import 'dart:convert';

import 'package:buildbeacon_core/buildbeacon_core.dart';

import 'model_edit.dart';
import 'wall_geometry.dart';

/// The parametric model of the tiles, in hardware/cad of the repository.
///
/// The parameter names used here (`part`, `label`, `master`, `master_logo`,
/// `link_count`) are a contract with that file: a test checks that it still
/// declares them. When the model changes version, update this name.
const cadModelFile = 'buildbeacon_tile_v1.5.scad';

/// Parameter sets file: OpenSCAD loads it on its own when it sits next to the
/// model with the same name.
final cadParamsFile = cadModelFile.replaceFirst(RegExp(r'\.scad$'), '.json');

/// A part to print: a parameter set of the model.
final class PrintPart {
  const PrintPart({
    required this.set,
    required this.parameters,
    this.tile,
    this.copies = 1,
  });

  /// Name of the parameter set, also used for the STL file: `app-tile`.
  final String set;

  /// The tile it belongs to (`null` for parts shared by several tiles).
  final Tile? tile;

  /// How many times to print it: the back plate of the project tiles is
  /// the same for all of them.
  final int copies;

  /// Values as OpenSCAD writes them in a parameter set: text for every type
  /// (`"true"`, `"5"`, the string itself).
  final Map<String, String> parameters;

  String get part => parameters['part']!;
}

/// What to print for a wall: a shell per tile (each with its name, the
/// master with the logo), the back plate of the master (it holds the ESP32),
/// one back plate for the project tiles to print as many times as there are
/// tiles (they are all the same: the name is only on the shell), and the dog
/// bones that join the back plates, one per side shared by two tiles.
final class PrintPlan {
  PrintPlan._(this.tiles, this.parts, this.links);

  factory PrintPlan.of(Config config) {
    // Master first, then the chain order: the order of the wiring.
    final tiles = [
      ...config.tiles.where((t) => t.kind == TileKind.master),
      ...config.projectTiles,
    ];
    final links = sharedSides(tiles.map((t) => t.pos));
    // Names of the shared parts, taken before the tiles.
    final used = <String>{'project-back', 'links'};
    String setName(Tile tile, String part) {
      final base = _safe(tile.id);
      var name = '$base-$part';
      for (var n = 2; !used.add(name); n++) {
        name = '$base-$n-$part';
      }
      return name;
    }

    final projects = tiles.where((t) => t.kind == TileKind.project).length;
    final parts = <PrintPart>[
      for (final tile in tiles) ...[
        PrintPart(
          set: setName(tile, 'tile'),
          tile: tile,
          parameters: {
            'part': 'tile',
            'label': tile.displayName,
            'master': '${tile.kind == TileKind.master}',
            'master_logo': '${tile.kind == TileKind.master}',
          },
        ),
        if (tile.kind == TileKind.master)
          PrintPart(
            set: setName(tile, 'back'),
            tile: tile,
            parameters: const {'part': 'back', 'master': 'true'},
          ),
      ],
      if (projects > 0)
        PrintPart(
          set: 'project-back',
          copies: projects,
          parameters: const {'part': 'back', 'master': 'false'},
        ),
      if (links > 0)
        PrintPart(
          set: 'links',
          parameters: {'part': 'links', 'link_count': '$links'},
        ),
    ];
    return PrintPlan._(tiles, parts, links);
  }

  /// The tiles, master first then in chain order.
  final List<Tile> tiles;
  final List<PrintPart> parts;

  /// Number of dog bones.
  final int links;

  /// The parameter sets file of OpenSCAD (Customizer, or `-p … -P set` on the
  /// command line).
  String toParameterSets() =>
      '${const JsonEncoder.withIndent('  ').convert({
        'parameterSets': {for (final part in parts) part.set: part.parameters},
        'fileFormatVersion': '1',
      })}\n';

  /// One command per part, to run in the folder of the model.
  List<String> commands() => [
    for (final part in parts)
      'openscad -p $cadParamsFile -P ${part.set} -o ${part.set}.stl '
          '$cadModelFile',
  ];

  /// Number of sides shared by two tiles placed at [positions].
  static int sharedSides(Iterable<HexPos> positions) {
    final cells = positions.toSet();
    var sides = 0;
    for (final cell in cells) {
      for (final (dq, dr) in WallGeometry.neighbors) {
        if (cells.contains(HexPos(cell.q + dq, cell.r + dr))) sides++;
      }
    }
    return sides ~/ 2;
  }

  /// A tile identifier usable as a set and file name.
  static String _safe(String id) {
    final name = id
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_-]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return name.isEmpty ? 'tile' : name;
  }
}
