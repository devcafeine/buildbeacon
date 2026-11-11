<!-- BuildBeacon Hub — plugin SDK. Version 1.2 (2026-11-11) — page d'entrée en anglais ; le guide complet passe dans docs/. -->
# BuildBeacon plugin SDK

The only dependency of a BuildBeacon **source plugin**: the plugin contract
(`SourcePlugin`), settings and secrets descriptions, source state, polling helper,
translated texts (`LocalizedText`), validation and testing tools (`testing.dart`).

```sh
mise run new-plugin my_source     # at the repository root: creates and registers a plugin
```

**Guide**: [Writing a plugin](../../docs/writing-a-plugin.md) ·
[Écrire un plugin (français)](../../docs/writing-a-plugin.fr.md)

Every public element is documented in [`lib/`](lib/). The GitHub Actions plugin
([`../plugins/github/`](../plugins/github/)) is a complete example.
