// BuildBeacon UI — "3D printing" panel: parts of the wall and OpenSCAD parameter sets.
// Version 1.0 (2026-11-12)

import 'package:buildbeacon_core/buildbeacon_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../editor/editor_controller.dart';
import '../editor/model_edit.dart';
import '../editor/print_plan.dart';
import '../platform/file_save.dart';
import 'fields.dart';
import 'l10n.dart';

/// Parts to print for the wall being edited, with the parametric model of
/// hardware/cad: a parameter sets file for the OpenSCAD Customizer, and the
/// commands that render every part.
class PrintPanel extends StatelessWidget {
  const PrintPanel({
    super.key,
    required this.editor,
    this.saveFile = saveTextFile,
  });

  final EditorController editor;
  final SaveTextFile saveFile;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final small = theme.textTheme.bodySmall;
    final plan = PrintPlan.of(editor.draft!);
    final commands = plan.commands().join('\n');

    void snack(String text) => ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        const SizedBox(height: 12),
        Text(l.printIntro(cadModelFile), style: small),
        SectionTitle(l.printParts),
        for (final tile in plan.tiles)
          ListTile(
            key: ValueKey('print:${tile.id}'),
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: Icon(
              tile.kind == TileKind.master
                  ? Icons.hexagon
                  : Icons.hexagon_outlined,
            ),
            title: Text(tile.displayName),
            subtitle: Text(
              tile.kind == TileKind.master
                  ? l.printMasterParts
                  : l.printTileParts,
            ),
          ),
        if (plan.parts.where((p) => p.set == 'project-back').firstOrNull
            case final backs?)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: const Icon(Icons.layers_outlined),
            title: Text(l.printBacks(backs.copies)),
          ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          leading: const Icon(Icons.link),
          title: Text(l.printLinks(plan.links)),
          subtitle: plan.links > 0 ? Text(l.printLinkTest) : null,
        ),
        Text(l.printNameHint, style: small),

        SectionTitle(l.printSets),
        Text(l.printSetsHelp(cadParamsFile), style: small),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonalIcon(
            icon: const Icon(Icons.download),
            label: Text(l.printDownload(cadParamsFile)),
            onPressed: () {
              final saved = saveFile(
                cadParamsFile,
                plan.toParameterSets(),
                'application/json',
              );
              if (!saved) snack(l.printDownloadUnavailable);
            },
          ),
        ),

        SectionTitle(l.printCommands),
        Text(l.printCommandsHelp, style: small),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          // One command per line, scrolled sideways rather than wrapped.
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SelectableText(
              commands,
              style: const TextStyle(fontSize: 12, height: 1.5),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.copy),
            label: Text(l.printCopy),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: commands));
              snack(l.printCopied);
            },
          ),
        ),
      ],
    );
  }
}
