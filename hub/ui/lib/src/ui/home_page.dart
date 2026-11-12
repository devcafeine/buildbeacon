// BuildBeacon UI — Main page: the wall, the panels, save / discard.
// Version 1.2 (2026-11-12) — "3D printing" tab.

import 'package:buildbeacon_core/buildbeacon_core.dart';
import 'package:flutter/material.dart';

import '../api/hub_api.dart';
import '../editor/editor_controller.dart';
import 'chain_panel.dart';
import 'l10n.dart';
import 'print_panel.dart';
import 'settings_panel.dart';
import 'tile_panel.dart';
import 'wall_view.dart';

/// Chosen language: `null` = the browser's.
typedef LanguageChoice = ValueNotifier<String?>;

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.editor, required this.language});

  final EditorController editor;
  final LanguageChoice language;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late final _tabs = TabController(length: 4, vsync: this);

  EditorController get editor => widget.editor;

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _select(String id) {
    editor.select(id);
    _tabs.animateTo(0);
  }

  void _add(HexPos pos) {
    if (editor.addTile(pos) != null) _tabs.animateTo(0);
  }

  void _snack(String text, {SnackBarAction? action}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text), action: action));
  }

  /// Runs [action]; asks for `BB_API_TOKEN` and retries if the Hub requires it.
  Future<ApiException?> _withToken(
    Future<ApiException?> Function() action,
  ) async {
    var error = await action();
    if (error != null && error.unauthorized && mounted) {
      if (await _askToken()) error = await action();
    }
    return error;
  }

  Future<bool> _askToken() async {
    final token = await showDialog<String>(
      context: context,
      builder: (context) => const _TokenDialog(),
    );
    if (token == null || token.trim().isEmpty) return false;
    editor.api.token = token.trim();
    return true;
  }

  Future<void> _save() async {
    final l = context.l10n;
    var result = await editor.save();
    if (result == SaveResult.unauthorized && mounted && await _askToken()) {
      result = await editor.save();
    }
    if (!mounted) return;
    switch (result) {
      case SaveResult.saved:
        _snack(l.saveDone);
      case SaveResult.rejected:
        _snack(l.saveRejected);
      case SaveResult.unauthorized:
        _snack(l.tokenRefused);
      case SaveResult.failed:
        _snack(apiErrorText(context, editor.lastError));
    }
  }

  Future<void> _identify(String id) async {
    final l = context.l10n;
    if (!editor.isSavedTile(id)) return _snack(l.identifyNeedsSave);
    final error = await _withToken(() => editor.identify(id));
    if (!mounted) return;
    _snack(error == null ? l.identifyStarted : apiErrorText(context, error));
  }

  Future<void> _checkWled() async {
    final error = await _withToken(editor.checkWled);
    if (!mounted || error == null) return;
    _snack(apiErrorText(context, error));
  }

  void _remove(String id) {
    final l = context.l10n;
    final before = editor.removeTile(id);
    if (before == null) return;
    _snack(
      l.tileRemoved,
      action: SnackBarAction(
        label: l.undo,
        onPressed: () => editor.restore(before),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: editor,
    builder: (context, _) {
      if (editor.loading) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (editor.loadError != null || editor.draft == null) {
        return _LoadFailed(editor: editor);
      }
      return Scaffold(
        appBar: _appBar(context),
        body: Column(
          children: [
            if (editor.remoteConfig != null) _RemoteBanner(editor: editor),
            if (editor.dirty && editor.issues.isNotEmpty)
              _IssuesBanner(issues: editor.issues),
            Expanded(child: _body(context)),
          ],
        ),
      );
    },
  );

  PreferredSizeWidget _appBar(BuildContext context) {
    final l = context.l10n;
    final narrow = MediaQuery.sizeOf(context).width < 600;
    return AppBar(
      title: Row(
        children: [
          const _Logo(),
          const SizedBox(width: 10),
          Text(l.appTitle),
          const SizedBox(width: 16),
          _LinkIndicator(link: editor.link, compact: narrow),
        ],
      ),
      actions: [
        _LanguageMenu(language: widget.language),
        if (narrow)
          IconButton(
            tooltip: l.discard,
            icon: const Icon(Icons.undo),
            onPressed: editor.dirty ? editor.discard : null,
          )
        else
          TextButton(
            onPressed: editor.dirty ? editor.discard : null,
            child: Text(l.discard),
          ),
        const SizedBox(width: 8),
        FilledButton.icon(
          icon: editor.saving
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: Text(
            editor.saving
                ? l.saving
                : editor.dirty
                ? l.save
                : l.saved,
          ),
          onPressed:
              editor.dirty &&
                  !editor.saving &&
                  !editor.validating &&
                  editor.issues.isEmpty
              ? _save
              : null,
        ),
        const SizedBox(width: 12),
      ],
    );
  }

  Widget _body(BuildContext context) {
    final l = context.l10n;
    final wall = WallView(editor: editor, onSelect: _select, onAdd: _add);
    final panel = Column(
      children: [
        TabBar(
          controller: _tabs,
          // Each tab as wide as its label: the four fit in the panel, and the
          // bar scrolls on a narrow screen instead of cutting the labels.
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelPadding: const EdgeInsets.symmetric(horizontal: 14),
          tabs: [
            Tab(text: l.tabTile),
            Tab(text: l.tabChain),
            Tab(text: l.tabSettings),
            Tab(text: l.tabPrint),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              TilePanel(
                editor: editor,
                onIdentify: _identify,
                onRemove: _remove,
              ),
              ChainPanel(
                editor: editor,
                onSelect: _select,
                onIdentify: _identify,
              ),
              SettingsPanel(editor: editor, onCheckWled: _checkWled),
              PrintPanel(editor: editor),
            ],
          ),
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 900) {
          return Row(
            children: [
              Expanded(child: wall),
              const VerticalDivider(width: 1),
              SizedBox(width: 440, child: panel),
            ],
          );
        }
        return Column(
          children: [
            SizedBox(height: constraints.maxHeight * 0.42, child: wall),
            Expanded(child: panel),
          ],
        );
      },
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) => Icon(
    Icons.hexagon_outlined,
    color: Theme.of(context).colorScheme.primary,
  );
}

class _LinkIndicator extends StatelessWidget {
  const _LinkIndicator({required this.link, required this.compact});

  final HubLink link;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final (color, text) = switch (link) {
      HubLink.connecting => (Colors.amber, l.linkConnecting),
      HubLink.live => (const Color(0xFF3CC46A), l.linkLive),
      HubLink.lost => (Theme.of(context).colorScheme.error, l.linkLost),
    };
    return Tooltip(
      message: text,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 10, color: color),
          if (!compact) ...[
            const SizedBox(width: 6),
            Text(text, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

class _LanguageMenu extends StatelessWidget {
  const _LanguageMenu({required this.language});

  final LanguageChoice language;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return PopupMenuButton<String>(
      tooltip: l.language,
      icon: const Icon(Icons.translate),
      initialValue: language.value ?? 'auto',
      onSelected: (value) => language.value = value == 'auto' ? null : value,
      itemBuilder: (context) => [
        PopupMenuItem(value: 'auto', child: Text(l.languageAuto)),
        const PopupMenuItem(value: 'en', child: Text('English')),
        const PopupMenuItem(value: 'fr', child: Text('Français')),
      ],
    );
  }
}

class _RemoteBanner extends StatelessWidget {
  const _RemoteBanner({required this.editor});

  final EditorController editor;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return MaterialBanner(
      leading: const Icon(Icons.sync_problem),
      content: Text(l.remoteChanged),
      actions: [
        TextButton(onPressed: editor.keepMine, child: Text(l.remoteKeepMine)),
        FilledButton.tonal(
          onPressed: editor.loadRemote,
          child: Text(l.remoteLoad),
        ),
      ],
    );
  }
}

class _IssuesBanner extends StatelessWidget {
  const _IssuesBanner({required this.issues});

  final List<LocalizedText> issues;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = TextStyle(color: scheme.onErrorContainer);
    return Container(
      width: double.infinity,
      color: scheme.errorContainer,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      constraints: const BoxConstraints(maxHeight: 160),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.issuesTitle(issues.length),
              style: style.copyWith(fontWeight: FontWeight.w600),
            ),
            for (final issue in issues)
              Text('• ${issue.of(context)}', style: style),
          ],
        ),
      ),
    );
  }
}

class _TokenDialog extends StatefulWidget {
  const _TokenDialog();

  @override
  State<_TokenDialog> createState() => _TokenDialogState();
}

class _TokenDialogState extends State<_TokenDialog> {
  final _token = TextEditingController();

  @override
  void dispose() {
    _token.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.tokenTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.tokenExplain),
          const SizedBox(height: 12),
          TextField(
            controller: _token,
            autofocus: true,
            obscureText: true,
            decoration: InputDecoration(labelText: l.tokenLabel),
            onSubmitted: (value) => Navigator.pop(context, value),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _token.text),
          child: Text(l.ok),
        ),
      ],
    );
  }
}

class _LoadFailed extends StatelessWidget {
  const _LoadFailed({required this.editor});

  final EditorController editor;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 48),
              const SizedBox(height: 16),
              Text(
                l.loadFailed,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                apiErrorText(context, editor.loadError),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(onPressed: editor.start, child: Text(l.retry)),
            ],
          ),
        ),
      ),
    );
  }
}
