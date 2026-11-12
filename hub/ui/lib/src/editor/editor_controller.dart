// BuildBeacon UI — Editor state: Hub configuration, draft, live state.
// Version 1.1 (2026-11-12) — comments in English.

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:buildbeacon_core/buildbeacon_core.dart';
import 'package:flutter/foundation.dart';

import '../api/hub_api.dart';
import '../api/hub_events.dart';
import '../api/live_state.dart';
import '../api/plugin_info.dart';
import 'model_edit.dart';

/// Connection to the Hub's live stream.
enum HubLink { connecting, live, lost }

enum SaveResult { saved, rejected, unauthorized, failed }

/// What the interface shows and edits.
///
/// Changes go into a draft ([draft]): the wall preview shows it right away
/// (computed here from the live source states), the Hub validates it as
/// changes come in ([issues]) and only applies it on save ([save]).
final class EditorController extends ChangeNotifier {
  EditorController(
    this.api, {
    this.validationDelay = const Duration(milliseconds: 300),
  });

  final HubApi api;

  /// Delay after the last change before asking the Hub to validate the
  /// draft.
  final Duration validationDelay;

  List<PluginInfo> plugins = const [];
  LiveState live = LiveState.empty;
  HubLink link = HubLink.connecting;

  bool loading = true;
  ApiException? loadError;

  String? selectedTileId;

  /// Issues of the draft according to the Hub; empty if it is valid.
  List<LocalizedText> issues = const [];
  bool validating = false;
  bool saving = false;

  /// Last save error.
  ApiException? lastError;

  /// Newer version saved on the Hub (file edited by hand, another tab)
  /// while the draft has changes.
  Config? remoteConfig;

  Config? _saved;
  Config? _draft;
  StreamSubscription<HubEvent>? _events;
  Timer? _validation;
  int _validationRun = 0;
  bool _disposed = false;

  /// Configuration applied by the Hub.
  Config? get saved => _saved;

  /// Configuration being edited.
  Config? get draft => _draft;

  bool get dirty => _draft != null && !_draft!.sameAs(_saved);

  Tile? get selectedTile {
    final id = selectedTileId;
    return id == null ? null : _draft?.tile(id);
  }

  PluginInfo? plugin(String type) {
    for (final plugin in plugins) {
      if (plugin.type == type) return plugin;
    }
    return null;
  }

  /// Last known state of [source]; unknown if the Hub does not read it
  /// (yet).
  SourceState stateOf(SourceConfig source) =>
      live.sources[source.key] ?? SourceState.unknown;

  /// Does the Hub already read this source (saved configuration)?
  bool isRead(SourceConfig source) => live.sources.containsKey(source.key);

  /// Does the tile exist in the Hub's configuration (to identify it)?
  bool isSavedTile(String id) => _saved?.tile(id) != null;

  // -------------------------------------------------------------------------
  // Loading and live stream

  Future<void> start() async {
    loading = true;
    loadError = null;
    _notify();
    try {
      plugins = await api.plugins();
      _saved = _draft = await api.config();
    } on ApiException catch (e) {
      loadError = e;
    } on FormatException {
      loadError = const ApiException(500);
    }
    loading = false;
    _notify();
    if (loadError == null) _events ??= api.events().listen(_onEvent);
  }

  void _onEvent(HubEvent event) {
    switch (event) {
      case HubLinkChanged(:final open):
        link = open ? HubLink.live : HubLink.lost;
      case HubMessage(name: 'config', :final data):
        _onRemoteConfig(data);
      case HubMessage(name: 'state', :final data):
        try {
          live = LiveState.fromJson(jsonDecode(data) as Map<String, Object?>);
          link = HubLink.live;
        } on Object {
          return;
        }
      case HubMessage():
        return;
    }
    _notify();
  }

  void _onRemoteConfig(String data) {
    final Config remote;
    try {
      remote = Config.fromJson(jsonDecode(data) as Map<String, Object?>);
    } on Object {
      return;
    }
    if (remote.sameAs(_saved)) return;
    if (!dirty) {
      _saved = _draft = remote;
      remoteConfig = null;
      issues = const [];
      _keepSelection();
    } else if (remote.sameAs(_draft)) {
      // Our draft, saved (the PUT response has not arrived yet).
      _saved = remote;
      remoteConfig = null;
    } else {
      remoteConfig = remote;
    }
  }

  /// Drops the draft in favor of the Hub's version ([remoteConfig]).
  void loadRemote() {
    final remote = remoteConfig;
    if (remote == null) return;
    _saved = _draft = remote;
    remoteConfig = null;
    _draftChanged();
  }

  /// Keeps the draft: saving it will replace the Hub's version.
  void keepMine() {
    final remote = remoteConfig;
    if (remote == null) return;
    _saved = remote;
    remoteConfig = null;
    _draftChanged();
  }

  // -------------------------------------------------------------------------
  // Draft changes

  void select(String? tileId) {
    selectedTileId = tileId;
    _notify();
  }

  void updateTile(String id, Tile Function(Tile tile) change) => _edit(
    (c) => c.copyWith(
      tiles: [for (final t in c.tiles) t.id == id ? change(t) : t],
    ),
  );

  /// Changes a tile's id; `false` if it is empty or already taken.
  bool renameTile(String id, String newId) {
    final name = newId.trim();
    final draft = _draft;
    if (draft == null || name.isEmpty) return false;
    if (name == id) return true;
    if (draft.tile(name) != null) return false;
    // Move the selection first: the change checks that it exists.
    if (selectedTileId == id) selectedTileId = name;
    updateTile(id, (t) => t.copyWith(id: name));
    return true;
  }

  /// Adds a project tile at [pos], at the end of the chain; returns its id.
  String? addTile(HexPos pos) {
    final draft = _draft;
    if (draft == null || draft.tileAt(pos) != null) return null;
    final rank =
        draft.projectTiles.fold(0, (last, t) => max(last, t.chainIndex)) + 1;
    var n = rank;
    while (draft.tile('tile-$n') != null) {
      n++;
    }
    final tile = Tile(
      id: 'tile-$n',
      label: '',
      kind: TileKind.project,
      chainIndex: rank,
      pos: pos,
    );
    selectedTileId = tile.id;
    _edit((c) => c.copyWith(tiles: [...c.tiles, tile]));
    return tile.id;
  }

  /// Removes a project tile; the following ones in the chain move up one
  /// position. Returns the previous draft, for "Undo" ([restore]).
  Config? removeTile(String id) {
    final draft = _draft;
    final tile = draft?.tile(id);
    if (draft == null || tile == null || tile.kind == TileKind.master) {
      return null;
    }
    if (selectedTileId == id) selectedTileId = null;
    _edit(
      (c) => _withChain(c, [
        for (final t in c.projectTiles)
          if (t.id != id) t.id,
      ], tiles: c.tiles.where((t) => t.id != id)),
    );
    return draft;
  }

  void restore(Config draft) {
    _draft = draft;
    _draftChanged();
  }

  /// Puts tile [id] at [pos]; if a tile is already there, they swap
  /// places.
  void moveTile(String id, HexPos pos) {
    final draft = _draft;
    final tile = draft?.tile(id);
    if (draft == null || tile == null || tile.pos == pos) return;
    final other = draft.tileAt(pos);
    _edit(
      (c) => c.copyWith(
        tiles: [
          for (final t in c.tiles)
            if (t.id == id)
              t.copyWith(pos: pos)
            else if (t.id == other?.id)
              t.copyWith(pos: tile.pos)
            else
              t,
        ],
      ),
    );
  }

  /// Moves the project tile at chain position `from + 1` to position
  /// `to + 1`; the others shift.
  void moveInChain(int from, int to) {
    final draft = _draft;
    if (draft == null) return;
    final ids = [for (final t in draft.projectTiles) t.id];
    if (from < 0 || from >= ids.length || to < 0 || to >= ids.length) return;
    ids.insert(to, ids.removeAt(from));
    _edit((c) => _withChain(c, ids));
  }

  void setZone(String tileId, ZoneName zone, ZoneAction? action) =>
      updateTile(tileId, (t) => t.withZone(zone, action));

  /// Action suggested when a zone is turned on: the source of another zone
  /// of the tile, otherwise the first plugin; history on the dots if the
  /// source provides one.
  ZoneAction defaultAction(Tile tile, ZoneName zone) {
    final source =
        tile.zones.values.firstOrNull?.source ??
        SourceConfig(type: plugins.firstOrNull?.type ?? 'github');
    final history =
        zone.modes.contains(DisplayMode.history) &&
        (plugin(source.type)?.providesHistory ?? false);
    return ZoneAction(
      source: source,
      mode: history ? DisplayMode.history : DisplayMode.overall,
    );
  }

  void setWled(WledConfig wled) => _edit((c) => c.copyWith(wled: wled));

  void setPollSeconds(int seconds) =>
      _edit((c) => c.copyWith(pollSeconds: seconds));

  void setColor(Status status, Rgb color) =>
      _edit((c) => c.copyWith(palette: c.palette.withColor(status, color)));

  void resetPalette() => _edit((c) => c.copyWith(palette: Palette()));

  /// Goes back to the Hub's configuration.
  void discard() {
    _draft = _saved;
    _draftChanged();
  }

  // -------------------------------------------------------------------------
  // Actions on the Hub

  Future<SaveResult> save() async {
    final draft = _draft;
    if (draft == null || !dirty || saving) return SaveResult.saved;
    saving = true;
    _notify();
    try {
      final config = await api.saveConfig(draft);
      _saved = config;
      // Changed while saving: the draft still needs to be saved.
      if (identical(_draft, draft)) _draft = config;
      remoteConfig = null;
      lastError = null;
      issues = const [];
      _scheduleValidation();
      return SaveResult.saved;
    } on ApiException catch (e) {
      lastError = e;
      if (e.unauthorized) return SaveResult.unauthorized;
      if (e.status == 422) {
        issues = e.issues;
        return SaveResult.rejected;
      }
      return SaveResult.failed;
    } finally {
      saving = false;
      _keepSelection();
      _notify();
    }
  }

  /// Makes a tile blink on the wall; the error, if any.
  Future<ApiException?> identify(String tileId) =>
      _attempt(() => api.identify(tileId));

  /// Checks WLED again; the error, if any.
  Future<ApiException?> checkWled() => _attempt(api.checkWled);

  Future<ApiException?> _attempt(Future<void> Function() action) async {
    try {
      await action();
      return null;
    } on ApiException catch (e) {
      return e;
    }
  }

  // -------------------------------------------------------------------------

  void _edit(Config Function(Config config) change) {
    final draft = _draft;
    if (draft == null) return;
    _draft = change(draft);
    _draftChanged();
  }

  void _draftChanged() {
    _keepSelection();
    _scheduleValidation();
    _notify();
  }

  void _scheduleValidation() {
    _validation?.cancel();
    final run = ++_validationRun;
    if (!dirty) {
      issues = const [];
      validating = false;
      return;
    }
    validating = true;
    _validation = Timer(validationDelay, () async {
      final draft = _draft!;
      List<LocalizedText>? found;
      try {
        found = await api.validate(draft);
      } on ApiException catch (e) {
        // Hub unreachable (or an older Hub that requires the token to
        // validate): validation resumes at the next change, and saving has
        // the last word.
        if (!e.unauthorized && e.message != null) found = [e.message!];
      }
      if (run != _validationRun) return;
      if (found != null) issues = found;
      validating = false;
      _notify();
    });
  }

  void _keepSelection() {
    final id = selectedTileId;
    if (id != null && _draft?.tile(id) == null) selectedTileId = null;
  }

  static Config _withChain(
    Config config,
    List<String> order, {
    Iterable<Tile>? tiles,
  }) {
    final rank = {for (final (i, id) in order.indexed) id: i + 1};
    return config.copyWith(
      tiles: [
        for (final t in tiles ?? config.tiles)
          if (t.kind == TileKind.project && rank[t.id] != null)
            t.copyWith(chainIndex: rank[t.id])
          else
            t,
      ],
    );
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _validation?.cancel();
    unawaited(_events?.cancel());
    super.dispose();
  }
}
