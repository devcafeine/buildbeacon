// BuildBeacon Hub — API publique du serveur.
// Version 1.7 (2026-11-12) — résolution du nom de WLED (host_resolver, mDNS).

/// Serveur BuildBeacon : plugins intégrés, exécution des sources, sortie des
/// LED vers WLED (DDP) et simulateur.
library;

export 'src/api/api.dart';
export 'src/api/snapshot.dart';
export 'src/builtin_plugins.dart';
export 'src/config_file.dart';
export 'src/env_file.dart';
export 'src/hub.dart';
export 'src/hub_service.dart';
export 'src/output/ddp.dart';
export 'src/output/ddp_sender.dart';
export 'src/output/host_resolver.dart';
export 'src/output/led_output_loop.dart';
export 'src/output/wled_client.dart';
export 'src/simulator/ddp_receiver.dart';
export 'src/simulator/terminal_panel.dart';
export 'src/simulator/web_simulator.dart';
export 'src/source_manager.dart';
