// BuildBeacon UI — "Settings" panel: WLED, brightness, polling, colors, sources.
// Version 1.1 (2026-11-12) — comments in English.

import 'package:buildbeacon_core/buildbeacon_core.dart';
import 'package:flutter/material.dart';

import '../api/live_state.dart';
import '../editor/editor_controller.dart';
import '../editor/model_edit.dart';
import 'fields.dart';
import 'l10n.dart';

class SettingsPanel extends StatelessWidget {
  const SettingsPanel({
    super.key,
    required this.editor,
    required this.onCheckWled,
  });

  final EditorController editor;
  final VoidCallback onCheckWled;

  /// Above 50 %, flicker observed with a USB-C power supply.
  static const comfortableBrightness = 128;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final small = theme.textTheme.bodySmall;
    final config = editor.draft!;
    final wled = config.wled;
    final percent = (wled.brightness * 100 / 255).round();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        SectionTitle(l.settingsWled),
        SyncedTextField(
          value: wled.host,
          label: l.wledHost,
          helper: l.wledHostHelp,
          onChanged: (host) => editor.setWled(wled.copyWith(host: host.trim())),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: IntField(
                value: wled.port,
                label: l.wledHttpPort,
                min: 1,
                max: 65535,
                onChanged: (port) => editor.setWled(wled.copyWith(port: port)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: IntField(
                value: wled.ddpPort,
                label: l.wledDdpPort,
                min: 1,
                max: 65535,
                onChanged: (port) =>
                    editor.setWled(wled.copyWith(ddpPort: port)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          l.wledBrightness(percent, wled.brightness),
          style: theme.textTheme.labelLarge,
        ),
        Slider(
          value: wled.brightness.toDouble(),
          max: 255,
          divisions: 255,
          label: '$percent %',
          onChanged: (value) =>
              editor.setWled(wled.copyWith(brightness: value.round())),
        ),
        Text(
          wled.brightness > comfortableBrightness
              ? l.wledBrightnessHigh
              : l.wledBrightnessHelp,
          style: wled.brightness > comfortableBrightness
              ? small?.copyWith(color: theme.colorScheme.error)
              : small,
        ),
        const SizedBox(height: 12),
        _WledStatus(editor: editor),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.wifi_find),
            label: Text(l.wledCheck),
            onPressed: onCheckWled,
          ),
        ),
        if (editor.dirty && !config.wled.sameAs(editor.saved?.wled))
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(l.wledCheckSavedOnly, style: small),
          ),

        SectionTitle(l.settingsPolling),
        IntField(
          value: config.pollSeconds,
          label: l.pollSeconds,
          suffix: 's',
          min: Config.minPollSeconds,
          helper: l.pollHelp(Config.minPollSeconds),
          onChanged: editor.setPollSeconds,
        ),

        SectionTitle(l.settingsColors),
        for (final status in Status.values)
          _ColorRow(
            key: ValueKey('color:${status.json}'),
            status: status,
            color: config.palette[status],
            onChanged: (color) => editor.setColor(status, color),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.restart_alt),
            label: Text(l.colorsReset),
            onPressed: editor.resetPalette,
          ),
        ),

        SectionTitle(l.settingsSources),
        for (final plugin in editor.plugins)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plugin.label.of(context),
                  style: theme.textTheme.titleSmall,
                ),
                Text(plugin.description.of(context), style: small),
                for (final secret in plugin.secrets)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Icon(
                          secret.configured
                              ? Icons.key
                              : Icons.key_off_outlined,
                          size: 16,
                          color: secret.configured
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            secret.configured
                                ? l.secretConfigured(secret.env)
                                : l.secretMissing(secret.env),
                            style: small,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        Text(l.secretsHelp, style: small),
      ],
    );
  }
}

extension on WledConfig {
  bool sameAs(WledConfig? other) =>
      other != null &&
      host == other.host &&
      port == other.port &&
      ddpPort == other.ddpPort &&
      brightness == other.brightness;
}

/// Result of the Hub's last WLED check.
class _WledStatus extends StatelessWidget {
  const _WledStatus({required this.editor});

  final EditorController editor;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final wled = editor.live.wled;
    final (icon, color, text) = switch (wled) {
      WledLive(checkedAt: null) => (
        Icons.help_outline,
        theme.colorScheme.onSurfaceVariant,
        l.wledNotChecked,
      ),
      WledLive(:final ledCount?, :final version, :final name) => (
        Icons.check_circle_outline,
        theme.colorScheme.primary,
        l.wledReachable(version ?? '?', name ?? 'WLED', ledCount),
      ),
      WledLive(:final error) => (
        Icons.portable_wifi_off,
        theme.colorScheme.onSurfaceVariant,
        l.wledUnreachable(error ?? '?'),
      ),
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: theme.textTheme.bodySmall)),
      ],
    );
  }
}

/// Color of a status: preview and `#RRGGBB` code.
class _ColorRow extends StatefulWidget {
  const _ColorRow({
    super.key,
    required this.status,
    required this.color,
    required this.onChanged,
  });

  final Status status;
  final Rgb color;
  final ValueChanged<Rgb> onChanged;

  @override
  State<_ColorRow> createState() => _ColorRowState();
}

class _ColorRowState extends State<_ColorRow> {
  bool _invalid = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final c = widget.color;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Color.fromARGB(255, c.r, c.g, c.b),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.status.label.titleOf(context)),
                if (widget.status.pulses)
                  Text(l.colorPulses, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          SizedBox(
            width: 120,
            child: SyncedTextField(
              value: c.toHex(),
              error: _invalid ? l.colorExpected : null,
              same: (text, value) =>
                  text.trim().toUpperCase().replaceFirst('#', '') ==
                  value.replaceFirst('#', ''),
              onChanged: (text) {
                Rgb? color;
                try {
                  color = Rgb.parse(text.trim());
                } on FormatException {
                  color = null;
                }
                if ((color == null) != _invalid) {
                  setState(() => _invalid = color == null);
                }
                if (color != null) widget.onChanged(color);
              },
            ),
          ),
        ],
      ),
    );
  }
}
