// BuildBeacon UI — "Tile" panel: name, id, zones (source + display mode).
// Version 1.1 (2026-11-12) — comments in English.

import 'package:buildbeacon_core/buildbeacon_core.dart';
import 'package:flutter/material.dart';

import '../api/plugin_info.dart';
import '../editor/editor_controller.dart';
import '../editor/model_edit.dart';
import 'fields.dart';
import 'l10n.dart';

class TilePanel extends StatelessWidget {
  const TilePanel({
    super.key,
    required this.editor,
    required this.onIdentify,
    required this.onRemove,
  });

  final EditorController editor;
  final ValueChanged<String> onIdentify;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tile = editor.selectedTile;
    if (tile == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            l.tileNoneSelected,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
    }
    final master = tile.kind == TileKind.master;
    final leds = master || tile.chainIndex >= 1
        ? LedLayout.tileIndices(tile.kind, tile.chainIndex)
        : const <int>[];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                tile.displayName,
                style: Theme.of(context).textTheme.titleLarge,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              tooltip: l.identifyTooltip,
              icon: const Icon(Icons.flare),
              onPressed: () => onIdentify(tile.id),
            ),
            if (!master)
              IconButton(
                tooltip: l.tileRemove,
                icon: const Icon(Icons.delete_outline),
                onPressed: () => onRemove(tile.id),
              ),
          ],
        ),
        Text(
          [
            tile.kind.label.titleOf(context),
            l.tileChainRank(tile.chainIndex),
            if (leds.isNotEmpty) l.ledRange(leds.first, leds.last),
          ].join(' · '),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        SyncedTextField(
          key: ValueKey('label:${tile.id}'),
          value: tile.label,
          label: l.tileLabel,
          helper: l.tileLabelHelp,
          onChanged: (label) =>
              editor.updateTile(tile.id, (t) => t.copyWith(label: label)),
        ),
        const SizedBox(height: 12),
        _IdField(key: ValueKey('id:${tile.id}'), editor: editor, tile: tile),
        for (final zone in tile.kind.zones) ...[
          const SizedBox(height: 16),
          ZoneEditor(
            key: ValueKey('zone:${tile.id}:${zone.name}'),
            editor: editor,
            tile: tile,
            zone: zone,
          ),
        ],
      ],
    );
  }
}

/// Id: applied when leaving the field (or on Enter), if it is not taken.
class _IdField extends StatefulWidget {
  const _IdField({super.key, required this.editor, required this.tile});

  final EditorController editor;
  final Tile tile;

  @override
  State<_IdField> createState() => _IdFieldState();
}

class _IdFieldState extends State<_IdField> {
  final _focus = FocusNode();
  String? _pending;
  String? _error;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit();
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _commit() {
    final value = _pending;
    if (value == null) return;
    final l = context.l10n;
    final name = value.trim();
    final taken =
        name != widget.tile.id && widget.editor.draft?.tile(name) != null;
    final error = name.isEmpty
        ? l.tileIdEmpty
        : taken
        ? l.tileIdTaken(name)
        : null;
    setState(() => _error = error);
    // Renamed: the panel is rebuilt with the new key.
    if (error == null) widget.editor.renameTile(widget.tile.id, name);
  }

  @override
  Widget build(BuildContext context) => SyncedTextField(
    value: widget.tile.id,
    focusNode: _focus,
    label: context.l10n.tileId,
    helper: context.l10n.tileIdHelp,
    error: _error,
    onChanged: (value) => _pending = value,
    onSubmitted: (_) => _commit(),
  );
}

/// A zone of the tile: off, or a source and a display mode.
class ZoneEditor extends StatelessWidget {
  const ZoneEditor({
    super.key,
    required this.editor,
    required this.tile,
    required this.zone,
  });

  final EditorController editor;
  final Tile tile;
  final ZoneName zone;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final action = tile.zones[zone];
    final theme = Theme.of(context);
    return Card.outlined(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 12, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        zone.label.titleOf(context),
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(switch (zone) {
                        ZoneName.ambient => l.zoneAmbientHelp,
                        ZoneName.dots => l.zoneDotsHelp,
                        ZoneName.system => l.zoneSystemHelp,
                      }, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                Switch(
                  value: action != null,
                  onChanged: (on) => editor.setZone(
                    tile.id,
                    zone,
                    on ? editor.defaultAction(tile, zone) : null,
                  ),
                ),
              ],
            ),
            if (action == null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(l.zoneOff, style: theme.textTheme.bodySmall),
              )
            else
              ..._actionFields(context, action),
          ],
        ),
      ),
    );
  }

  void _set(ZoneAction action) => editor.setZone(tile.id, zone, action);

  List<Widget> _actionFields(BuildContext context, ZoneAction action) {
    final l = context.l10n;
    final plugin = editor.plugin(action.source.type);
    final source = action.source;
    final modes = [
      for (final mode in DisplayMode.values)
        if (zone.modes.contains(mode)) mode,
    ];
    final numeric =
        action.mode == DisplayMode.thresholds ||
        action.mode == DisplayMode.gauge;
    final unit = plugin?.metrics
        .where((m) => m.id == action.metric)
        .firstOrNull
        ?.unit;

    return [
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        key: ValueKey('type:${source.type}'),
        initialValue: source.type,
        isExpanded: true,
        decoration: InputDecoration(labelText: l.zoneSource),
        items: [
          for (final p in editor.plugins)
            DropdownMenuItem(value: p.type, child: Text(p.label.of(context))),
          if (plugin == null)
            DropdownMenuItem(
              value: source.type,
              child: Text(l.pluginUnknown(source.type)),
            ),
        ],
        onChanged: (type) {
          if (type == null || type == source.type) return;
          final next = editor.plugin(type);
          _set(
            action.copyWith(
              source: SourceConfig(type: type),
              mode: next == null || next.supports(action.mode)
                  ? action.mode
                  : DisplayMode.overall,
            ),
          );
        },
      ),
      if (plugin != null) ...[
        for (final field in plugin.settings) ...[
          const SizedBox(height: 12),
          SettingInput(
            key: ValueKey('setting:${source.type}:${field.id}'),
            field: field,
            value: source.settings[field.id],
            onChanged: (value) => _set(
              action.copyWith(source: source.withSetting(field.id, value)),
            ),
          ),
        ],
        for (final secret in plugin.secrets)
          if (!secret.configured) _SecretNotice(secret: secret),
      ],
      const SizedBox(height: 16),
      Text(l.zoneMode, style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(height: 6),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final mode in modes)
            Tooltip(
              message: plugin == null || plugin.supports(mode)
                  ? _modeHelp(context, mode)
                  : l.modeUnsupported,
              child: ChoiceChip(
                label: Text(mode.label.titleOf(context)),
                selected: action.mode == mode,
                onSelected: plugin == null || plugin.supports(mode)
                    ? (_) => _set(action.copyWith(mode: mode))
                    : null,
              ),
            ),
        ],
      ),
      const SizedBox(height: 6),
      Text(
        _modeHelp(context, action.mode),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      if (numeric) ..._numericFields(context, action, plugin, unit),
      const SizedBox(height: 12),
      _SourceLive(editor: editor, source: source),
    ];
  }

  String _modeHelp(BuildContext context, DisplayMode mode) {
    final l = context.l10n;
    return switch (mode) {
      DisplayMode.overall => l.modeOverallHelp,
      DisplayMode.history => l.modeHistoryHelp,
      DisplayMode.thresholds => l.modeThresholdsHelp,
      DisplayMode.gauge => l.modeGaugeHelp,
    };
  }

  List<Widget> _numericFields(
    BuildContext context,
    ZoneAction action,
    PluginInfo? plugin,
    String? unit,
  ) {
    final l = context.l10n;
    final thresholds = action.thresholds;
    final metrics = plugin?.metrics ?? const <MetricInfo>[];
    return [
      const SizedBox(height: 12),
      if (metrics.isNotEmpty)
        DropdownButtonFormField<String?>(
          key: ValueKey('metric:${action.metric}'),
          initialValue: metrics.any((m) => m.id == action.metric)
              ? action.metric
              : null,
          isExpanded: true,
          decoration: InputDecoration(labelText: l.metric),
          items: [
            DropdownMenuItem(value: null, child: Text(l.metricFirst)),
            for (final m in metrics)
              DropdownMenuItem(
                value: m.id,
                child: Text(
                  m.unit == null
                      ? m.label.of(context)
                      : '${m.label.of(context)} (${m.unit})',
                ),
              ),
          ],
          onChanged: (id) => _set(action.copyWith(metric: id)),
        )
      else
        SyncedTextField(
          value: action.metric ?? '',
          label: l.metric,
          helper: l.metricFreeHelp,
          onChanged: (text) => _set(
            action.copyWith(metric: text.trim().isEmpty ? null : text.trim()),
          ),
        ),
      const SizedBox(height: 12),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: OptionalNumberField(
              value: thresholds.warning,
              label: l.thresholdWarning,
              suffix: unit,
              onChanged: (value) => _set(
                action.copyWith(
                  thresholds: thresholds.copyWith(warning: value),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OptionalNumberField(
              value: thresholds.failure,
              label: l.thresholdFailure,
              suffix: unit,
              onChanged: (value) => _set(
                action.copyWith(
                  thresholds: thresholds.copyWith(failure: value),
                ),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      SegmentedButton<AlertDirection>(
        segments: [
          for (final direction in AlertDirection.values)
            ButtonSegment(
              value: direction,
              label: Text(
                direction == AlertDirection.above ? l.alertAbove : l.alertBelow,
              ),
            ),
        ],
        selected: {thresholds.direction},
        onSelectionChanged: (selection) => _set(
          action.copyWith(
            thresholds: thresholds.copyWith(direction: selection.first),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          action.mode == DisplayMode.gauge
              ? l.thresholdsGaugeHelp
              : l.thresholdsHelp,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
      if (action.mode == DisplayMode.gauge) ...[
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: OptionalNumberField(
                value: action.min,
                label: l.gaugeMin,
                suffix: unit,
                onChanged: (value) => _set(action.copyWith(min: value)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OptionalNumberField(
                value: action.max,
                label: l.gaugeMax,
                suffix: unit,
                onChanged: (value) => _set(action.copyWith(max: value)),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            l.gaugeBoundsHelp,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    ];
  }
}

/// Secret missing on the Hub: its help text (e.g. "public repositories only").
class _SecretNotice extends StatelessWidget {
  const _SecretNotice({required this.secret});

  final SecretInfo secret;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = secret.required
        ? theme.colorScheme.error
        : theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.key_off_outlined, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              [
                context.l10n.secretMissing(secret.env),
                ?secret.help?.of(context),
              ].join(' '),
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// Last known state of the source, according to the Hub.
class _SourceLive extends StatelessWidget {
  const _SourceLive({required this.editor, required this.source});

  final EditorController editor;
  final SourceConfig source;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final small = theme.textTheme.bodySmall;
    if (!editor.isRead(source)) {
      return Text(l.sourceNotRead, style: small);
    }
    final state = editor.stateOf(source);
    final palette = editor.draft!.palette;
    Widget dot(Status status, {double size = 12}) {
      final rgb = palette[status];
      return Tooltip(
        message: status.label.titleOf(context),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Color.fromARGB(255, rgb.r, rgb.g, rgb.b),
            shape: BoxShape.circle,
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            dot(state.status),
            const SizedBox(width: 8),
            Text(
              l.sourceNow(state.status.label.of(context)),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(width: 12),
            for (final status in state.history.take(5)) ...[
              dot(status, size: 9),
              const SizedBox(width: 3),
            ],
          ],
        ),
        for (final MapEntry(key: id, value: metric) in state.metrics.entries)
          Text(
            l.metricLine(
              id,
              '${formatNumber(metric.value)}'
              '${metric.unit == null ? '' : ' ${metric.unit}'}',
            ),
            style: small,
          ),
        if (state.error case final error?)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              error.of(context),
              style: small?.copyWith(color: theme.colorScheme.error),
            ),
          ),
      ],
    );
  }
}
