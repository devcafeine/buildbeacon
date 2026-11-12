// BuildBeacon Hub — Plugin SDK: testing tools.
// Version 1.1 (2026-11-12) — comments in English.

/// Tools to test a plugin without the Hub or the network: simulated context
/// ([fakeContext]) and reading of the first states ([firstState],
/// [firstStates]). Conformance is checked with `conformanceIssues`, exported
/// by the main library.
library;

export 'src/testing/plugin_harness.dart';
