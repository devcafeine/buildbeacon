// BuildBeacon UI — "Chain" panel: wiring order of the tiles, LED count.
// Version 1.1 (2026-11-12) — comments in English.

import 'package:buildbeacon_core/buildbeacon_core.dart';
import 'package:flutter/material.dart';

import '../editor/editor_controller.dart';
import '../editor/model_edit.dart';
import 'l10n.dart';

/// The chain order is the wiring order, independent of the position on the
/// wall: the master tile first, then the project tiles, reordered by
/// dragging them (the `mise run test-pattern` test pattern helps find it).
class ChainPanel extends StatelessWidget {
  const ChainPanel({
    super.key,
    required this.editor,
    required this.onSelect,
    required this.onIdentify,
  });

  final EditorController editor;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onIdentify;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final config = editor.draft!;
    final master = config.tiles
        .where((t) => t.kind == TileKind.master)
        .firstOrNull;
    final tiles = config.projectTiles;

    Widget row(Tile tile, {Widget? handle}) {
      final leds = tile.kind == TileKind.master || tile.chainIndex >= 1
          ? LedLayout.tileIndices(tile.kind, tile.chainIndex)
          : const <int>[];
      return ListTile(
        key: ValueKey('chain:${tile.id}'),
        selected: tile.id == editor.selectedTileId,
        leading: CircleAvatar(radius: 16, child: Text('${tile.chainIndex}')),
        title: Text(tile.displayName, overflow: TextOverflow.ellipsis),
        subtitle: Text(leds.isEmpty ? '—' : l.ledRange(leds.first, leds.last)),
        onTap: () => onSelect(tile.id),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: l.identifyTooltip,
              icon: const Icon(Icons.flare),
              onPressed: () => onIdentify(tile.id),
            ),
            ?handle,
          ],
        ),
      );
    }

    final wled = editor.live.wled;
    final expected = config.ledCount;
    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      padding: const EdgeInsets.only(bottom: 32),
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(l.chainHelp, style: theme.textTheme.bodySmall),
          ),
          if (master != null) row(master),
          const Divider(height: 1),
        ],
      ),
      footer: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.chainLedTotal(expected), style: theme.textTheme.bodyMedium),
            const SizedBox(height: 4),
            if (wled.ledCount case final actual?)
              Text(
                actual == expected
                    ? l.chainWledMatches(actual)
                    : l.chainWledMismatch(actual, expected),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: actual == expected ? null : theme.colorScheme.error,
                ),
              )
            else
              Text(l.chainWledUnknown, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
      itemCount: tiles.length,
      onReorderItem: editor.moveInChain,
      itemBuilder: (context, index) => row(
        tiles[index],
        handle: ReorderableDragStartListener(
          index: index,
          child: Tooltip(
            message: l.chainDrag,
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.drag_handle),
            ),
          ),
        ),
      ),
    );
  }
}
