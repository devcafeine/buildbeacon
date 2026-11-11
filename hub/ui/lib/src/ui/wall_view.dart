// BuildBeacon UI — Le mur : tuiles à leur place, LED en direct, ajout et déplacement.
// Version 1.0 (2026-11-11)

import 'dart:math';

import 'package:buildbeacon_core/buildbeacon_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import '../editor/editor_controller.dart';
import '../editor/model_edit.dart';
import '../editor/wall_geometry.dart';
import 'l10n.dart';

/// Couleurs du mur (toujours sombre : les LED ressortent comme au vrai mur).
final class WallColors {
  const WallColors({
    required this.wall,
    this.tile = const Color(0xFF242A2E),
    this.edge = const Color(0xFF353D42),
    this.text = const Color(0xFFB9C2C7),
    this.muted = const Color(0xFF6E7A80),
    this.dotOff = const Color(0xFF171C1F),
    this.accent = const Color(0xFF59C2CC),
  });

  static const light = WallColors(wall: Color(0xFF15191B));
  static const dark = WallColors(wall: Color(0xFF0A0D0E));

  final Color wall;
  final Color tile;
  final Color edge;
  final Color text;
  final Color muted;
  final Color dotOff;
  final Color accent;
}

/// Le mur, dessiné d'après le brouillon et animé (pulsation des runs en
/// cours, clignotement « identifier »).
///
/// Toucher une tuile la sélectionne, toucher un « + » ajoute une tuile,
/// glisser une tuile la déplace (sur une autre : échange de places).
class WallView extends StatefulWidget {
  const WallView({
    super.key,
    required this.editor,
    required this.onSelect,
    required this.onAdd,
  });

  final EditorController editor;
  final ValueChanged<String> onSelect;
  final ValueChanged<HexPos> onAdd;

  @override
  State<WallView> createState() => _WallViewState();
}

class _WallViewState extends State<WallView>
    with SingleTickerProviderStateMixin {
  static const _renderer = FrameRenderer();

  late final Ticker _ticker = createTicker(
    (elapsed) => setState(() => _time = elapsed),
  );
  Duration _time = Duration.zero;
  String? _dragId;
  Offset? _dragPoint;
  HexPos? _hover;

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(WallView old) {
    super.didUpdateWidget(old);
    _syncTicker();
  }

  /// L'animation ne tourne que si une LED bouge.
  void _syncTicker() {
    final animated = widget.editor.live.animated;
    if (animated && !_ticker.isActive) {
      _ticker.start();
    } else if (!animated && _ticker.isActive) {
      _ticker.stop();
      _time = Duration.zero;
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editor = widget.editor;
    final config = editor.draft!;
    final colors = Theme.of(context).brightness == Brightness.dark
        ? WallColors.dark
        : WallColors.light;
    final frame = _renderer.render(
      config,
      editor.live.sources,
      _time,
      identify: editor.live.identifying,
    );
    final free = WallGeometry.freeNeighbors(config.tiles.map((t) => t.pos));
    final bounds = WallGeometry.bounds([
      ...config.tiles.map((t) => t.pos),
      ...free,
    ]);

    return ColoredBox(
      color: colors.wall,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          const margin = 12.0;
          final scale = min(
            (size.width - 2 * margin) / bounds.width,
            (size.height - 2 * margin) / bounds.height,
          ).clamp(0.4, 6.0);
          final origin =
              Offset(
                (size.width - bounds.width * scale) / 2,
                (size.height - bounds.height * scale) / 2,
              ) -
              bounds.topLeft * scale;
          Offset toWall(Offset point) => (point - origin) / scale;
          HexPos cellAt(Offset point) => WallGeometry.hexAt(toWall(point));

          final hoverTile = _hover == null ? null : config.tileAt(_hover!);
          final cursor = _dragId != null
              ? SystemMouseCursors.grabbing
              : hoverTile != null
              ? SystemMouseCursors.click
              : _hover != null && free.contains(_hover)
              ? SystemMouseCursors.click
              : MouseCursor.defer;

          return MouseRegion(
            cursor: cursor,
            onHover: (event) {
              final cell = cellAt(event.localPosition);
              if (cell != _hover) setState(() => _hover = cell);
            },
            onExit: (_) => setState(() => _hover = null),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) {
                final cell = cellAt(details.localPosition);
                if (config.tileAt(cell) case final tile?) {
                  widget.onSelect(tile.id);
                } else if (free.contains(cell)) {
                  widget.onAdd(cell);
                }
              },
              onPanStart: (details) {
                final tile = config.tileAt(cellAt(details.localPosition));
                if (tile == null) return;
                setState(() {
                  _dragId = tile.id;
                  _dragPoint = toWall(details.localPosition);
                });
              },
              onPanUpdate: (details) {
                if (_dragId == null) return;
                setState(() => _dragPoint = toWall(details.localPosition));
              },
              onPanEnd: (_) => _endDrag(),
              onPanCancel: () => setState(() {
                _dragId = null;
                _dragPoint = null;
              }),
              child: CustomPaint(
                size: size,
                painter: WallPainter(
                  config: config,
                  frame: frame,
                  free: free,
                  origin: origin,
                  scale: scale,
                  colors: colors,
                  textStyle: DefaultTextStyle.of(context).style,
                  selectedId: editor.selectedTileId,
                  hover: _hover,
                  dragId: _dragId,
                  dragPoint: _dragPoint,
                  addLabel: context.l10n.wallAddTile,
                  tileHint: context.l10n.wallTileHint,
                  onSelect: widget.onSelect,
                  onAdd: widget.onAdd,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _endDrag() {
    final id = _dragId;
    final point = _dragPoint;
    setState(() {
      _dragId = null;
      _dragPoint = null;
    });
    if (id == null || point == null) return;
    final target = WallGeometry.hexAt(point);
    widget.editor.moveTile(id, target);
    widget.onSelect(id);
  }
}

/// Dessin du mur, en millimètres (mis à l'échelle de la place disponible).
class WallPainter extends CustomPainter {
  WallPainter({
    required this.config,
    required this.frame,
    required this.free,
    required this.origin,
    required this.scale,
    required this.colors,
    required this.textStyle,
    required this.selectedId,
    required this.addLabel,
    required this.tileHint,
    required this.onSelect,
    required this.onAdd,
    this.hover,
    this.dragId,
    this.dragPoint,
  });

  final Config config;
  final LedFrame frame;
  final Set<HexPos> free;
  final Offset origin;
  final double scale;
  final WallColors colors;
  final TextStyle textStyle;
  final String? selectedId;
  final HexPos? hover;
  final String? dragId;
  final Offset? dragPoint;
  final String addLabel;
  final String tileHint;
  final ValueChanged<String> onSelect;
  final ValueChanged<HexPos> onAdd;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..translate(origin.dx, origin.dy)
      ..scale(scale);

    for (final pos in free) {
      _paintFreeSlot(canvas, pos);
    }
    final target = dragPoint == null ? null : WallGeometry.hexAt(dragPoint!);
    if (dragId != null && target != null) {
      canvas.drawPath(
        WallGeometry.hexagon(WallGeometry.center(target), scale: 0.97),
        Paint()..color = colors.accent.withValues(alpha: 0.18),
      );
    }
    for (final tile in config.tiles) {
      final dragged = tile.id == dragId && dragPoint != null;
      _paintTile(
        canvas,
        tile,
        WallGeometry.center(tile.pos),
        opacity: dragged ? 0.35 : 1,
      );
    }
    if (config.tiles.where((t) => t.id == dragId).firstOrNull case final tile?
        when dragPoint != null) {
      _paintTile(canvas, tile, dragPoint!, opacity: 0.85);
    }
    canvas.restore();
  }

  void _paintFreeSlot(Canvas canvas, HexPos pos) {
    final center = WallGeometry.center(pos);
    final hovered = pos == hover && dragId == null;
    final path = WallGeometry.hexagon(center, scale: 0.97);
    if (hovered) {
      canvas.drawPath(
        path,
        Paint()..color = colors.tile.withValues(alpha: 0.5),
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6
        ..color = colors.edge.withValues(alpha: hovered ? 1 : 0.35),
    );
    // Discret tant que la souris n'est pas dessus : le mur reste lisible.
    final plus = Paint()
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..color = (hovered ? colors.accent : colors.muted).withValues(
        alpha: hovered ? 1 : 0.4,
      );
    canvas
      ..drawLine(center - const Offset(5, 0), center + const Offset(5, 0), plus)
      ..drawLine(
        center - const Offset(0, 5),
        center + const Offset(0, 5),
        plus,
      );
  }

  void _paintTile(
    Canvas canvas,
    Tile tile,
    Offset center, {
    required double opacity,
  }) {
    Color fade(Color color) => color.withValues(alpha: color.a * opacity);
    final selected = tile.id == selectedId;
    final master = tile.kind == TileKind.master;

    canvas.drawPath(
      WallGeometry.hexagon(center, scale: 0.97),
      Paint()..color = fade(colors.tile),
    );
    canvas.drawPath(
      WallGeometry.hexagon(center, scale: 0.97),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 1.6 : 0.6
        ..color = fade(selected ? colors.accent : colors.edge),
    );

    // LED : halo flou, limité à la tuile, comme derrière le plastique.
    final positions = master
        ? WallGeometry.masterLeds
        : WallGeometry.projectLeds;
    final validRank = master || tile.chainIndex >= 1;
    final indices = validRank
        ? LedLayout.tileIndices(tile.kind, tile.chainIndex)
        : const <int>[];
    Color? ledColor(int local) {
      if (local >= indices.length || indices[local] >= frame.length) {
        return null;
      }
      final rgb = frame[indices[local]];
      if (rgb == Rgb.black) return null;
      return Color.fromARGB(255, rgb.r, rgb.g, rgb.b);
    }

    canvas
      ..save()
      ..clipPath(WallGeometry.hexagon(center, scale: 0.95));
    for (final (local, position) in positions.indexed) {
      final color = ledColor(local);
      if (color == null) continue;
      final isDot = !master && local >= 2 && local <= 6;
      canvas.drawCircle(
        center + position,
        master ? 8.5 : (isDot ? 5 : 10),
        Paint()
          ..color = fade(color.withValues(alpha: 0.9))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5),
      );
    }
    canvas.restore();

    if (!master) {
      for (var local = 2; local <= 6; local++) {
        final color = ledColor(local);
        canvas.drawCircle(
          center + WallGeometry.projectLeds[local],
          3.3,
          Paint()..color = fade(color ?? colors.dotOff),
        );
      }
    }

    final name = tile.displayName;
    if (master) {
      final logo = WallGeometry.hexagon(
        center + const Offset(0, -14),
        scale: 0.17,
      );
      canvas.drawPath(
        logo,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = fade(colors.text),
      );
      _text(canvas, name, center + const Offset(0, 21), 8, fade(colors.text));
    } else {
      _text(canvas, name, center + const Offset(0, -17), 10, fade(colors.text));
    }
    _text(
      canvas,
      '${tile.chainIndex}',
      center + const Offset(0, 37),
      6,
      fade(colors.muted),
    );
  }

  void _text(Canvas canvas, String text, Offset at, double size, Color color) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: textStyle.copyWith(
          fontSize: size,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: 60);
    painter.paint(canvas, at - Offset(painter.width / 2, painter.height / 2));
    painter.dispose();
  }

  /// Zones accessibles (lecteurs d'écran, tests) : une par tuile et par « + ».
  @override
  SemanticsBuilderCallback get semanticsBuilder => (size) {
    Rect rect(HexPos pos) {
      final c = origin + WallGeometry.center(pos) * scale;
      return Rect.fromCenter(
        center: c,
        width: WallGeometry.flat * scale * 0.8,
        height: WallGeometry.flat * scale * 0.8,
      );
    }

    return [
      for (final tile in config.tiles)
        CustomPainterSemantics(
          key: ValueKey('tile:${tile.id}'),
          rect: rect(tile.pos),
          properties: SemanticsProperties(
            label: tile.displayName,
            hint: tileHint,
            button: true,
            selected: tile.id == selectedId,
            textDirection: TextDirection.ltr,
            onTap: () => onSelect(tile.id),
          ),
        ),
      for (final pos in free)
        CustomPainterSemantics(
          key: ValueKey('free:${pos.q},${pos.r}'),
          rect: rect(pos),
          properties: SemanticsProperties(
            label: addLabel,
            button: true,
            textDirection: TextDirection.ltr,
            onTap: () => onAdd(pos),
          ),
        ),
    ];
  };

  @override
  bool shouldRepaint(WallPainter oldDelegate) => true;

  @override
  bool shouldRebuildSemantics(WallPainter oldDelegate) =>
      oldDelegate.config != config ||
      oldDelegate.selectedId != selectedId ||
      oldDelegate.origin != origin ||
      oldDelegate.scale != scale ||
      oldDelegate.addLabel != addLabel;
}
