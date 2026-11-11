// BuildBeacon Hub — API publique du serveur.
// Version 1.5 (2026-11-11) — le Hub (programme principal), lecture du .env, API JSON de WLED.

/// Serveur BuildBeacon : plugins intégrés, exécution des sources, sortie des
/// LED vers WLED (DDP) et simulateur.
library;

export 'src/builtin_plugins.dart';
export 'src/config_file.dart';
export 'src/env_file.dart';
export 'src/hub.dart';
export 'src/output/ddp.dart';
export 'src/output/ddp_sender.dart';
export 'src/output/led_output_loop.dart';
export 'src/output/wled_client.dart';
export 'src/simulator/ddp_receiver.dart';
export 'src/simulator/terminal_panel.dart';
export 'src/simulator/web_simulator.dart';
export 'src/source_manager.dart';
