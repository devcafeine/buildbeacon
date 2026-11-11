// BuildBeacon Hub — API publique du serveur.
// Version 1.4 (2026-11-11) — simulateur web (page + SSE).

/// Serveur BuildBeacon : plugins intégrés, exécution des sources, sortie des
/// LED vers WLED (DDP) et simulateur.
library;

export 'src/builtin_plugins.dart';
export 'src/config_file.dart';
export 'src/output/ddp.dart';
export 'src/output/ddp_sender.dart';
export 'src/output/led_output_loop.dart';
export 'src/simulator/ddp_receiver.dart';
export 'src/simulator/terminal_panel.dart';
export 'src/simulator/web_simulator.dart';
export 'src/source_manager.dart';
