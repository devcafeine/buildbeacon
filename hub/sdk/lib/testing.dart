// BuildBeacon Hub — SDK des plugins : outils de test.
// Version 1.0 (2026-11-11)

/// Outils pour tester un plugin sans le Hub ni le réseau :
/// contexte simulé ([fakeContext]) et lecture des premiers états
/// ([firstState], [firstStates]). La conformité se vérifie avec
/// `conformanceIssues`, exporté par la bibliothèque principale.
library;

export 'src/testing/plugin_harness.dart';
